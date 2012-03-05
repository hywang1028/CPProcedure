--按渠道统计支付代付总交易量
--输入支付日期、代付日期
--输出Sales.Channel,Sales.Area,Sales.BranchOffice,Sales.IndustryName,MerchantName,MerchantNo,Sales.MerchantType,OpenTime,TransCount,TransAmount
With Payment as
(
	select
		MerchantNo,
		SUM(SucceedTransCount) TransCount,
		SUM(SucceedTransAmount) TransAmount
	from
		FactDailyTrans
	where
		DailyTransDate >= '2012-01-01'
		and
		DailyTransDate < '2012-02-01'
	group by
		MerchantNo
),
Ora as
(
	Select
		MerchantNo,
		SUM(TransCount) TransCount,
		SUM(TransAmount) TransAmount
	from
		Table_OraTransSum
	where
		CPDate >= '2012-01-01'
		and
		CPDate < '2012-02-01'
	group by
		MerchantNo
)
select * into #AllData from Payment
union all
select * from Ora;

select
	Sales.Channel,
	Sales.Area,
	Sales.BranchOffice,
	Sales.IndustryName,
	coalesce(MerInfo.MerchantName,OraMer.MerchantName,Sales.MerchantName) MerchantName,
	coalesce(Trans.MerchantNo,Sales.MerchantNo) MerchantNo,
	Sales.MerchantType,
	Convert(char(10),coalesce(MerInfo.OpenTime,OraMer.OpenTime),120) OpenTime,
	ISNULL(Trans.TransCount,0) as TransCount,
	Convert(decimal,ISNULL(Trans.TransAmount,0))/100 as TransAmount
from
	#AllData Trans
	full outer join
	Table_SalesDeptConfiguration Sales
	on
		Sales.MerchantNo = Trans.MerchantNo
	left join
	Table_MerInfo MerInfo
	on
		coalesce(Trans.MerchantNo,Sales.MerchantNo) = MerInfo.MerchantNo
	left join
	Table_OraMerchants OraMer
	on
		coalesce(Trans.MerchantNo,Sales.MerchantNo) = OraMer.MerchantNo;
	
Drop table #AllData;
