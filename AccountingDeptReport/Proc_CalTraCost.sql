if OBJECT_ID(N'Proc_CalTraCost', N'P') is not null
begin
	drop procedure Proc_CalTraCost
end
go

create procedure Proc_CalTraCost
	@StartDate datetime,
	@EndDate datetime
as
begin

--1. Check input params
if isnull(@StartDate, N'') = N'' or isnull(@EndDate, N'') = N''
begin
	raiserror(N'Input params cannot be empty in Proc_CalTraCost',16,1);
end

--2. Adjust @EndDate
set @EndDate = DATEADD(day,1,@EndDate);

--3. Calculate cost
select
	tra.MerchantNo,
	tra.ChannelNo,
	tra.TransType,
	tra.CPDate,
	tra.TotalCnt,
	tra.TotalAmt,
	tra.SucceedCnt,
	tra.SucceedAmt,
	tra.CalFeeCnt,
	tra.CalFeeAmt,
	tra.CalCostCnt,
	tra.CalCostAmt,
	tra.FeeAmt,
	case when 
		costRule.FeeType = 'Fixed'
	then
		tra.CalCostCnt * costRule.FeeValue
	when
		costRule.FeeType = 'Percent'
	then
		tra.CalCostAmt * costRule.FeeValue
	else
		0
	end CostAmt
from
	Table_TraScreenSum tra
	outer apply
	(select top(1)
		FeeType,
		FeeValue
	from
		Table_TraCostRuleByChannel
	where
		ChannelNo = tra.ChannelNo
		and
		ApplyDate <= tra.CPDate
	order by
		ApplyDate desc) costRule
where
	tra.CPDate >= @StartDate
	and
	tra.CPDate < @EndDate;


end



