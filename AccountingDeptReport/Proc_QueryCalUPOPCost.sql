-- [Created] At 20130402 By 王红燕：UPOP成本计算子存储过程
--Input:StartDate,EndDate
--Output:MerchantNo,TransDate,CdFlag,TransAmt,TransCnt,FeeAmt,CostAmt
if OBJECT_ID(N'Proc_CalUPOPCost',N'P') is not null
begin
	drop procedure Proc_CalUPOPCost;
end
go

create procedure Proc_CalUPOPCost
	@StartDate datetime = '2012-01-01',
	@EndDate datetime = '2013-02-02'
as
begin

--1. Check Input
if(@StartDate is null or @EndDate is null)
begin
	raiserror(N'Input params can`t be empty in Proc_CalUPOPCost',16,1);
end;

--2. Get Trans Detail
With UPOPTrans as
(
	select
		GateNo,
		MerchantNo,
		CdFlag,
		TransDate,
		SUM(PurCnt) TransCnt,
		SUM(PurAmt) TransAmt,
		SUM(FeeAmt) FeeAmt
	from
		Table_UpopliqFeeLiqResult
	where
		TransDate >= @StartDate
		and
		TransDate <  @EndDate
	group by
		GateNo,
		MerchantNo,
		CdFlag,
		TransDate
),
--3. Get Rule Type and Rule Value 
--3.1 get Trans with ApplyDate
ByMerTransWithApplyDate as
(
	select
		UPOPTrans.MerchantNo,
		UPOPTrans.TransDate,
		UPOPTrans.CdFlag,
		UPOPCostRule.RuleObject,
		max(UPOPCostRule.ApplyDate) ApplyDate
	from
		UPOPTrans
		inner join
		Table_UpopCostRule UPOPCostRule
		on
			UPOPTrans.MerchantNo = UPOPCostRule.RuleObject
			and
			UPOPTrans.TransDate >= UPOPCostRule.ApplyDate
	where
		UPOPCostRule.CostRuleType = 'ByMer'
	group by
		UPOPTrans.MerchantNo,
		UPOPTrans.TransDate,
		UPOPTrans.CdFlag,
		UPOPCostRule.RuleObject
),
ByMccTransWithApplyDate as
(
	select
		UPOPTrans.MerchantNo,
		UPOPTrans.TransDate,
		UPOPTrans.CdFlag,
		UPOPCostRule.RuleObject,
		max(UPOPCostRule.ApplyDate) ApplyDate
	from
		UPOPTrans
		inner join
		Table_UpopCostRule UPOPCostRule
		on
			SUBSTRING(UPOPTrans.MerchantNo,8,4) = UPOPCostRule.RuleObject
			and
			UPOPTrans.TransDate >= UPOPCostRule.ApplyDate
	where
		UPOPCostRule.CostRuleType = 'ByMcc'  
		and
		UPOPTrans.MerchantNo not in (select distinct MerchantNo from ByMerTransWithApplyDate)
	group by
		UPOPTrans.MerchantNo,
		UPOPTrans.TransDate,
		UPOPTrans.CdFlag,
		UPOPCostRule.RuleObject
),
ByCdTransWithApplyDate as
(
	select
		UPOPTrans.MerchantNo,
		UPOPTrans.TransDate,
		UPOPTrans.CdFlag,
		UPOPCostRule.RuleObject,
		max(UPOPCostRule.ApplyDate) ApplyDate
	from
		UPOPTrans
		inner join
		Table_UpopCostRule UPOPCostRule
		on
			UPOPTrans.CdFlag = UPOPCostRule.RuleObject
			and
			UPOPTrans.TransDate >= UPOPCostRule.ApplyDate
	where
		UPOPCostRule.CostRuleType = 'ByCd'  
		and
		UPOPTrans.MerchantNo not in (select distinct MerchantNo from ByMerTransWithApplyDate)
		and
		UPOPTrans.MerchantNo not in (select distinct MerchantNo from ByMccTransWithApplyDate)
	group by
		UPOPTrans.MerchantNo,
		UPOPTrans.TransDate,
		UPOPTrans.CdFlag,
		UPOPCostRule.RuleObject
),
AllTransWithApplyDate as
(
	select * from ByMerTransWithApplyDate
	union all
	select * from ByMccTransWithApplyDate
	union all
	select * from ByCdTransWithApplyDate
)
--3.3 Get Trans with Rule Type
select
	UPOPTrans.GateNo,
	UPOPTrans.MerchantNo,
	UPOPTrans.TransDate,
	UPOPTrans.CdFlag,
	UPOPTrans.TransAmt,
	UPOPTrans.TransCnt,
	UPOPTrans.FeeAmt,
	case when UPOPCostRule.FeeType = 'Fixed'
		 then UPOPTrans.TransCnt * ISNULL(UPOPCostRule.FeeValue, 0)
		 when UPOPCostRule.FeeType = 'Percent'
		 then UPOPTrans.TransAmt * ISNULL(UPOPCostRule.FeeValue, 0)
		 Else 0 End as CostAmt 
from
	UPOPTrans 
	left join
	AllTransWithApplyDate ApplyDate
	on
		UPOPTrans.MerchantNo = ApplyDate.MerchantNo
		and
		UPOPTrans.TransDate = ApplyDate.TransDate
		and
		UPOPTrans.CdFlag = ApplyDate.CdFlag
	left join
	Table_UpopCostRule UPOPCostRule
	on
		ApplyDate.RuleObject = UPOPCostRule.RuleObject
		and
		ApplyDate.ApplyDate = UPOPCostRule.ApplyDate
end;


