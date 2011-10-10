if OBJECT_ID(N'Proc_QuerySalesMerTransReport', N'P') is not null
begin
	drop procedure Proc_QuerySalesMerTransReport;
end
go

create procedure Proc_QuerySalesMerTransReport
	@StartDate datetime = '2011-08-01',
	@EndDate datetime = '2011-08-31'
as
begin

--1. Check input
if (@StartDate is null or @EndDate is null)
begin
	raiserror(N'Input params cannot be empty in Proc_QuerySalesMerTransReport', 16, 1);
end

--2. Prepare Actually EndDate
set @EndDate = DATEADD(day,1,@EndDate);

--3. Get Trans Data
With CMCTransData as
(
	select
		MerchantNo,
		SUM(SucceedTransCount) as CurrSucceedCount,
		SUM(SucceedTransAmount) as CurrSucceedAmount
	from
		FactDailyTrans
	where
		DailyTransDate >= @StartDate
		and
		DailyTransDate < @EndDate
	group by
		MerchantNo
),
ORATransData as
(
	select
		MerchantNo,
		SUM(Table_OraTransSum.TransCount) as CurrSucceedCount,
		SUM(Table_OraTransSum.TransAmount) as CurrSucceedAmount
	from
		dbo.Table_OraTransSum
	where
		Table_OraTransSum.CPDate >= @StartDate
		and
		Table_OraTransSum.CPDate < @EndDate
	group by
		MerchantNo
)
select
	*
into
	#TransData
from
	CMCTransData
union all
select
	*
from
	ORATransData;
	
--4. Get Result
--4.1 Convert Currency Rate
update
	TD
set
	TD.CurrSucceedAmount = TD.CurrSucceedAmount * CR.CurrencyRate
from
	#TransData TD
	inner join
	Table_SalesCurrencyRate CR
	on
		TD.MerchantNo = CR.MerchantNo;

--6.2 Get Final Result
select 
	Sales.MerchantName,
	Sales.Area,
	Sales.SalesManager,
	Sales.MerchantNo,
	Sales.MerchantType,
	Sales.IndustryName,	
	Sales.Channel,
	Sales.BranchOffice,
	Sales.SigningYear,
	Sales.MerchantClass,
	Rate.CurrencyRate,
	Convert(decimal,ISNULL(Trans.CurrSucceedAmount,0))/100 CurrSucceedAmount,
	ISNULL(Trans.CurrSucceedCount,0) CurrSucceedCount
from
	dbo.Table_SalesDeptConfiguration Sales
	left join
	#TransData Trans
	on
		Sales.MerchantNo = Trans.MerchantNo
	left join
	Table_SalesCurrencyRate Rate
	on
		Sales.MerchantNo = Rate.MerchantNo
order by
	Sales.MerchantName;

--7. Clear temp table
drop table #TransData;

end 