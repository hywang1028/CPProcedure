--[Modified] At 2013-05-29 By chen.wu
--using function Fn_PaymentCostCalcExp to replace original logic

if OBJECT_ID(N'Proc_QueryGateNoCostRule', N'P') is not null
begin
	drop procedure Proc_QueryGateNoCostRule;
end
go

create procedure Proc_QueryGateNoCostRule
as
begin

select
	AllGate.GateNo,
	AllGate.GateDesc as GateName,
	(select 
		convert(varchar(10), MAX(ApplyDate), 102) 
	from 
		Table_GateCostRule 
	where 
		GateNo = AllGate.GateNo 
		and 
		ApplyDate <= GETDATE()) as ApplyDate,
	dbo.Fn_PaymentCostCalcExp(AllGate.GateNo, GETDATE()) as CostCalculateRule
from
	Table_GateRoute AllGate;

end