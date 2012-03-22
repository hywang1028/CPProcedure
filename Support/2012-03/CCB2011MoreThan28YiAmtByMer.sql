declare @cumulativePurAmt decimal(15,2);
set @cumulativePurAmt = 0.0;

declare @limitAmt decimal(15,2);
set @limitAmt = 280000000000.0;

declare @currPurAmt decimal(15,2);
declare @currEndDate datetime;

declare dailyTransCursor cursor forward_only 
for
	select
		PurAmt,
		FeeEndDate
	from
		Table_FeeCalcResult
	where
		GateNo in ('0010', '1010', '4010', '5010', '6010')
		and
		FeeEndDate >= '2011-01-01'	
	order by
		FeeEndDate;
		
open dailyTransCursor;
fetch next from dailyTransCursor into @currPurAmt, @currEndDate;
while @@FETCH_STATUS = 0
begin
	set @cumulativePurAmt = @cumulativePurAmt + @currPurAmt;
	if @cumulativePurAmt >= @limitAmt
	begin
		break
	end
	fetch next from dailyTransCursor into @currPurAmt, @currEndDate;
end

close dailyTransCursor;
deallocate dailyTransCursor;

select @cumulativePurAmt;
select @currEndDate;

With SumAmtByMer as
(
	select
		FeeResult.MerchantNo,
		SUM(isnull(PurAmt, 0))/100.0 as SumPurAmt,
		SUM(isnull(FeeAmt, 0))/100.0 as SumFeeAmt,
		SUM(isnull(LiqAmt, 0))/100.0 as SumLiqAmt 
	from
		Table_FeeCalcResult FeeResult
	where
		FeeResult.FeeEndDate > @currEndDate
		and
		FeeResult.FeeEndDate < '2012-01-01'
		and
		FeeResult.GateNo in ('0010', '1010', '4010', '5010', '6010')
	group by
		FeeResult.MerchantNo
)
select
	MerInfo.MerchantName,
	SumAmtByMer.*
from
	SumAmtByMer
	inner join
	Table_MerInfo MerInfo
	on
		SumAmtByMer.MerchantNo = MerInfo.MerchantNo
order by
	SumAmtByMer.MerchantNo;