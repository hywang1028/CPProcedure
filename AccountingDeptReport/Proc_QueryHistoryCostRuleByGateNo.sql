--[Modified] At 2013-05-29 by chen.wu
--using function Fn_PaymentCostCalcExp replace original logic


if OBJECT_ID(N'Proc_QueryHistoryCostRuleByGateNo', N'P') is not null
begin
	drop procedure Proc_QueryHistoryCostRuleByGateNo;
end
go
  
create procedure Proc_QueryHistoryCostRuleByGateNo  
 @GateNo as char(4) = '0055'  
as  
begin  
  
--1. Check input  
if (@GateNo is null)  
begin  
 raiserror(N'Input params cannot be empty in Proc_QueryHistoryCostRuleByGateNo', 16, 1);  
end;  
  
select
	GateNo,
	convert(varchar(10), ApplyDate, 102) as ApplyDate,
	dbo.Fn_PaymentCostCalcExp(GateNo, ApplyDate) as CostCalculateRule,
	CostRuleType
from
	Table_GateCostRule
where
	GateNo = @GateNo;  
  
end