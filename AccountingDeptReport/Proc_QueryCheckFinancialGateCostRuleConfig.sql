if OBJECT_ID(N'Proc_QueryCheckFinancialGateCostRuleConfig') is not null
begin
	drop procedure Proc_QueryCheckFinancialGateCostRuleConfig;
end
go

create procedure Proc_QueryCheckFinancialGateCostRuleConfig
as
begin

declare @Warn nvarchar(200);
set @Warn = '';

--1.1 Find all grouped GateNo
select
	GateNo,
	ApplyDate,
	GateGroup
into
	#GroupGate
from
	Table_CostRuleByYear
where
	GateGroup <> 0;
	
--1.2 Get NextApplyDate for #GroupGate
select
	GroupGate.GateNo,
	GroupGate.ApplyDate,
	GroupGate.GateGroup,
	MIN(isnull(GateCostRule.ApplyDate, '9999-01-01')) NextApplyDate
into
	#GroupGateWithNextApplyDate
from
	#GroupGate GroupGate
	left join
	Table_GateCostRule GateCostRule
	on
		GroupGate.GateNo = GateCostRule.GateNo
		and
		GroupGate.ApplyDate < GateCostRule.ApplyDate
group by
	GroupGate.GateNo,
	GroupGate.ApplyDate,
	GroupGate.GateGroup;
	

--1.3 Calc count by GateGroup,ApplyDate
select
	GateGroup,
	ApplyDate,
	COUNT(*) cnt
into
	#GateCnt1	
from
	#GroupGateWithNextApplyDate
group by
	GateGroup,
	ApplyDate;

--1.4 Calc count by GateGroup,ApplyDate,NextApplyDate
select
	GateGroup,
	ApplyDate,
	NextApplyDate,
	COUNT(*) cnt
into
	#GateCnt2	
from
	#GroupGateWithNextApplyDate
group by
	GateGroup,
	ApplyDate,
	NextApplyDate;

--1.5 Compare counts
select distinct
	GC1.GateGroup
into
	#Result
from
	#GateCnt1 GC1
	inner join
	#GateCnt2 GC2
	on
		GC1.GateGroup = GC2.GateGroup
		and
		GC1.ApplyDate = GC2.ApplyDate
where
	GC1.cnt <> GC2.cnt;


--2.1 Get GateRule From Table_GateCostRule
select
	CostRuleType,
	GateNo,
	ApplyDate
into
	#GateCostRule
from
	Table_GateCostRule
where
	CostRuleType <> 'ByUpop';
	
--2.2 Get GateRule From Partial 3 Tables
select
	'ByTrans' as CostRuleType,
	GateNo,
	ApplyDate 
into
	#CostRuleByPartialTables
from
	Table_CostRuleByTrans
union all
select
	'ByYear' as CostRuleType,
	GateNo,
	ApplyDate
from
	Table_CostRuleByYear
union all
select
	'ByMer' as CostRuleType,
	GateNo,
	ApplyDate
from
	Table_CostRuleByMer;
	
--2.3 Check Not Config Gate in Partitial 3 Tables
select
	GateCostRule.GateNo SGateNo,
	ByPartitial.GateNo PGateNo
into	
	#NotConfigInPartital
from
	#GateCostRule GateCostRule
	left join
	#CostRuleByPartialTables ByPartitial
	on
		GateCostRule.CostRuleType = ByPartitial.CostRuleType
		and
		GateCostRule.GateNo = ByPartitial.GateNo
		and
		GateCostRule.ApplyDate = ByPartitial.ApplyDate;

--2.4 Check Not Config Gate in GateCostRule
select
	ByPartitial.GateNo PGateNo,
	GateCostRule.GateNo SGateNo
into	
	#NotConfigInGateCostRule
from
	#CostRuleByPartialTables ByPartitial
	left join
	#GateCostRule GateCostRule
	on
		ByPartitial.CostRuleType = GateCostRule.CostRuleType
		and
		ByPartitial.GateNo = GateCostRule.GateNo
		and
		ByPartitial.ApplyDate = GateCostRule.ApplyDate;

if exists(select * from #Result)
begin
	set @Warn += N'包年网关组 ' + CONVERT(nvarchar(50),(select convert(char(2),GateGroup)+ ',' from #Result FOR XML PATH(''))) +N'成本规则配置不完全,请与系统管理员联系!';
end		

if exists(select * from  #NotConfigInPartital where PGateNo is null)
begin
	set @Warn += '网关号 ' + CONVERT(nvarchar(50),(select SGateNo + ',' from #NotConfigInPartital where PGateNo is null FOR XML PATH(''))) + N'未在子表中配置，请与系统管理员联系!';
end

if exists(select * from #NotConfigInGateCostRule where SGateNo is null)
begin
	set @Warn += N'网关号 ' + convert(nvarchar(50),(select PGateNo + ',' from #NotConfigInGateCostRule where SGateNo is null FOR XML PATH(''))) + N'未在网关成本规则表中配置，请与系统管理员联系!';
end

select @Warn as Warn;

 --Drop Temporary Tables
drop table #GroupGate;
drop table #GroupGateWithNextApplyDate;
drop table #GateCnt1;
drop table #GateCnt2;
drop table #Result;
drop table #GateCostRule;
drop table #CostRuleByPartialTables;
drop table #NotConfigInPartital;
drop table #NotConfigInGateCostRule;

end
