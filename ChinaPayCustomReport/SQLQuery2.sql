select
	Trans.MerchantNo,
	case when
		Trans.DailyTransDate >= '2010-01-01' and Trans.DailyTransDate < '2011-01-01'
	then
		N'2011年前交易量'
	when
		Trans.DailyTransDate >= '2011-01-01' and Trans.DailyTransDate < '2011-02-01'
	then
		N'2011年1月交易量'
	when
		Trans.DailyTransDate >= '2011-02-01' and Trans.DailyTransDate < '2011-03-01'
	then
		N'2011年2月交易量'
	when
		Trans.DailyTransDate >= '2011-03-01' and Trans.DailyTransDate < '2011-04-01'
	then
		N'2011年3月交易量'
	when
		Trans.DailyTransDate >= '2011-04-01' and Trans.DailyTransDate < '2011-05-01'
	then
		N'2011年4月交易量'
	when
		Trans.DailyTransDate >= '2011-05-01' and Trans.DailyTransDate < '2011-06-01'
	then
		N'2011年5月交易量'
	end as TradeDuration,
	SucceedTransCount,
	SucceedTransAmount
into
	#Trans
from
	FactDailyTrans Trans
where
	Trans.DailyTransDate < '2011-06-01';

		
select
	Trans.MerchantNo,
	Trans.TradeDuration,
	SUM(Trans.SucceedTransCount) SumCount,
	convert(decimal, SUM(Trans.SucceedTransAmount))/100 SumAmount
into
	#SumValue
from
	#Trans Trans
group by
	Trans.MerchantNo,
	Trans.TradeDuration;
	
select
	MerchantNo,
	
	SUM(case when TradeDuration = N'2011年前交易量' then SumCount else 0 end) as N'2011年前交易笔数',
	SUM(case when TradeDuration = N'2011年前交易量' then SumAmount else 0 end) as N'2011年前交易金额',
	
	SUM(case when TradeDuration = N'2011年1月交易量' then SumCount else 0 end) as N'2011年1月交易笔数',
	SUM(case when TradeDuration = N'2011年1月交易量' then SumAmount else 0 end) as N'2011年1月交易金额',
	
	SUM(case when TradeDuration = N'2011年2月交易量' then SumCount else 0 end) as N'2011年2月交易笔数',
	SUM(case when TradeDuration = N'2011年2月交易量' then SumAmount else 0 end) as N'2011年2月交易金额',

	SUM(case when TradeDuration = N'2011年3月交易量' then SumCount else 0 end) as N'2011年3月交易笔数',
	SUM(case when TradeDuration = N'2011年3月交易量' then SumAmount else 0 end) as N'2011年3月交易金额',

	SUM(case when TradeDuration = N'2011年4月交易量' then SumCount else 0 end) as N'2011年4月交易笔数',
	SUM(case when TradeDuration = N'2011年4月交易量' then SumAmount else 0 end) as N'2011年4月交易金额',

	SUM(case when TradeDuration = N'2011年5月交易量' then SumCount else 0 end) as N'2011年5月交易笔数',
	SUM(case when TradeDuration = N'2011年5月交易量' then SumAmount else 0 end) as N'2011年5月交易金额'
into
	#PivotSum
from
	#SumValue
group by
	MerchantNo;
	

select
	MerInfo.MerchantName,
	MerInfo.MerchantNo,
	case when 
		Config.Channel in (N'银商',N'银联') 
	then 
		N'银联'+ isnull(Config.Area, N'') + N'分公司'
	else
		N'ChinaPay'
	end as BranchName,
	
	case when
		Config.SigningYear is null or Config.SigningYear = 'History'
	then
		N'-'
	else
		Config.SigningYear
	end as OnlineYear,
	
	case when
		Config.MerchantType = N'代扣商户'
	then
		N'批扣'
	else
		N'网上支付'
	end as BizType,		
	isnull([2011年前交易笔数],0) as [2011年前交易笔数],
	isnull([2011年前交易金额],0) as [2011年前交易金额],
	
	isnull([2011年1月交易笔数],0) as [2011年1月交易笔数],
	isnull([2011年1月交易金额],0) as [2011年1月交易金额],
	
	isnull([2011年2月交易笔数],0) as [2011年2月交易笔数],
	isnull([2011年2月交易金额],0) as [2011年2月交易金额],

	isnull([2011年3月交易笔数],0) as [2011年3月交易笔数],
	isnull([2011年3月交易金额],0) as [2011年3月交易金额],

	isnull([2011年4月交易笔数],0) as [2011年4月交易笔数],
	isnull([2011年4月交易金额],0) as [2011年4月交易金额],

	isnull([2011年5月交易笔数],0) as [2011年5月交易笔数],
	isnull([2011年5月交易金额],0) as [2011年5月交易金额]
into
	#Result1
from
	#PivotSum PivotSum
	inner join
	Table_MerInfo MerInfo
	on
		PivotSum.MerchantNo = MerInfo.MerchantNo
	left join
	Table_SalesDeptConfiguration Config
	on
		PivotSum.MerchantNo = Config.MerchantNo;
		
select
	R1.*,
	R1.[2011年1月交易笔数] + R1.[2011年2月交易笔数] + R1.[2011年3月交易笔数] + R1.[2011年4月交易笔数] + R1.[2011年5月交易笔数] as [2011年1-5月交易笔数],
	R1.[2011年1月交易金额] + R1.[2011年2月交易金额] + R1.[2011年3月交易金额] + R1.[2011年4月交易金额] + R1.[2011年5月交易金额] as [2011年1-5月交易金额]
from
	#Result1 R1
	
	
drop table #Result1;
drop table #PivotSum;
drop table #SumValue;
drop table #Trans;