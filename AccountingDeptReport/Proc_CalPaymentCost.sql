-- [Created] At 20120306 By 叶博：支付成本子存储过程
--Input:StartDate,EndDate
--Output:GateNo,MerchantNo,FeeEndDate,TransCnt,TransAmt,CostAmt
--[Modified] At 2012-03-21 By Chen.wu  Add @HisRefDate param
--[Modified] At 2012-05-25 By 王红燕  Add @ConvertToRMB param
--[Modified] At 2013-05-28 By Chen.wu Add ByUpop Category
--[Modified] At 2013-07-29 By Chen.wu Modify column SubCostRuleValue(#GateMerRule), FeeValue(#CostRuleByUpop) to decimal(16,5)
--[Modified} At 2013-08-16 By Chen.wu change Table_CpUpopRelation to Table_CupsMerInfo

if OBJECT_ID(N'Proc_CalPaymentCost',N'P') is not null
begin
	drop procedure Proc_CalPaymentCost;
end
go

create procedure Proc_CalPaymentCost
	@StartDate datetime = '2013-03-01',
	@EndDate datetime = '2013-06-01',
	@HisRefDate datetime = null,
	@ConvertToRMB char(2) = null
as
begin

declare @MaxRef bigint;
declare @MinRef bigint;
set @MaxRef = 100000000000000;
set @MinRef = 0;

--1. Check Input
if(@StartDate is null or @EndDate is null)
begin
	raiserror(N'Input params can`t be empty in Proc_CalPaymentCost',16,1);
end

--2 get dailytrans
select
	Fee.GateNo,
	Fee.MerchantNo,
	Fee.FeeEndDate,
	Fee.PurCnt,
	Fee.PurAmt,
	Fee.FeeAmt,
	Fee.InstuFeeAmt,
	Fee.BankFeeAmt,
	case when 
		LEN(Fee.CdFlag) = 1
	then
		'0'+Fee.CdFlag
	else
		Fee.CdFlag
	end as CdFlag
into
	#FeeResult
from
	Table_FeeCalcResult Fee
where
	Fee.FeeEndDate >= @StartDate
	and
	Fee.FeeEndDate <  @EndDate

if @ConvertToRMB = 'on'
Begin
	With CuryRate as
	(
		select
			CuryCode,
			AVG(CuryRate) AVGCuryRate 
		from
			Table_CuryFullRate
		where
			CuryDate >= @StartDate
			and
			CuryDate <  @EndDate
		group by
			CuryCode		
	)
	update 
		Fee
	set
		Fee.PurAmt = ISNULL(CuryRate.AVGCuryRate, 1.0)*Fee.PurAmt,
		Fee.FeeAmt = ISNULL(CuryRate.AVGCuryRate, 1.0)*Fee.FeeAmt,
		Fee.InstuFeeAmt = ISNULL(CuryRate.AVGCuryRate, 1.0)*Fee.InstuFeeAmt,
		Fee.BankFeeAmt = ISNULL(CuryRate.AVGCuryRate, 1.0)*Fee.BankFeeAmt
	from
		#FeeResult Fee
		inner join
		Table_MerInfoExt MerInfo
		on
			Fee.MerchantNo = MerInfo.MerchantNo
		inner join
		CuryRate
		on
			MerInfo.CuryCode = CuryRate.CuryCode;
End
--3. determin rule type

--3.1 get daily trans with ApplyDate
create table #GateMerRule
(
	GateNo char(4) not null,
	MerchantNo char(20) not null,
	FeeEndDate datetime not null,
	SucceedTransCount bigint,
	SucceedTransAmount decimal(16,2),
	FeeAmt decimal(16,2),
	InstuFeeAmt decimal(16,2),
	BankFeeAmt decimal(16,2),
	CdFlag char(2),
	Cost decimal(18,4),
	CostRuleType varchar(20),
	ApplyDate datetime,
	NextApplyDate datetime,
	SubCostRuleType varchar(15),
	SubCostRuleValue decimal(16,5)
);

if @HisRefDate is not null
begin
	With OldestValidCostRule as
	(
		select
			GateNo,
			MIN(ApplyDate) ApplyDate
		from
			Table_GateCostRule
		where
			ApplyDate < @EndDate
		group by
			GateNo
	),
	RecentCostRule as
	(
		select
			GateNo,
			MAX(ApplyDate) ApplyDate
		from
			Table_GateCostRule
		where
			ApplyDate <= @HisRefDate
		group by
			GateNo
	)
	select
		OldestValidCostRule.GateNo,
		ISNULL(RecentCostRule.ApplyDate, OldestValidCostRule.ApplyDate) ApplyDate
	into
		#HisRuleKey
	from
		OldestValidCostRule
		left join
		RecentCostRule
		on
			OldestValidCostRule.GateNo = RecentCostRule.GateNo;
			
	
	With HisRule as
	(
		select
			GateCostRule.GateNo,
			GateCostRule.ApplyDate,
			GateCostRule.CostRuleType
		from
			#HisRuleKey HisRuleKey
			inner join
			Table_GateCostRule GateCostRule
			on
				HisRuleKey.GateNo = GateCostRule.GateNo
				and
				HisRuleKey.ApplyDate = GateCostRule.ApplyDate
	)	
	insert into
		#GateMerRule
		(
			GateNo,
			MerchantNo,
			FeeEndDate,
			SucceedTransCount,
			SucceedTransAmount,
			FeeAmt,
			InstuFeeAmt,
			BankFeeAmt,
			CdFlag,
			Cost,
			CostRuleType,
			ApplyDate,
			NextApplyDate,
			SubCostRuleType,
			SubCostRuleValue
		)
	select
		FeeResult.GateNo,
		FeeResult.MerchantNo,
		FeeResult.FeeEndDate,
		FeeResult.PurCnt as SucceedTransCount,
		FeeResult.PurAmt as SucceedTransAmount,
		FeeResult.FeeAmt,
		FeeResult.InstuFeeAmt,
		FeeResult.BankFeeAmt,
		FeeResult.CdFlag,
		0 as Cost,
		isnull(HisRule.CostRuleType, '') as CostRuleType,
		HisRule.ApplyDate,
		@EndDate NextApplyDate,
		'' as SubCostRuleType,
		0 as SubCostRuleValue
	from
		#FeeResult FeeResult
		left join
		HisRule
		on
			FeeResult.GateNo = HisRule.GateNo;
	
	--clear specific temp table		
	drop table #HisRuleKey;					
end
else
begin
	select
		FeeResult.GateNo,
		FeeResult.MerchantNo,
		FeeResult.FeeEndDate,
		max(GateCostRule.ApplyDate) ApplyDate
	into
		#FeeResultWithApplyDate
	from
		#FeeResult FeeResult
		left join
		Table_GateCostRule GateCostRule
		on
			FeeResult.GateNo = GateCostRule.GateNo
			and
			FeeResult.FeeEndDate >= GateCostRule.ApplyDate   
	group by
		FeeResult.GateNo,
		FeeResult.MerchantNo,
		FeeResult.FeeEndDate;
		
	--3.2 add NextApplyDate in #DailyTransWithApplyDate
	select
		FeeResultWithApplyDate.GateNo,
		FeeResultWithApplyDate.MerchantNo,
		FeeResultWithApplyDate.FeeEndDate,
		FeeResultWithApplyDate.ApplyDate,
		MIN(GateCostRule.ApplyDate) NextApplyDate
	into
		#FeeResultWithAllApplyDate
	from
		#FeeResultWithApplyDate FeeResultWithApplyDate
		left join
		Table_GateCostRule GateCostRule
		on
			FeeResultWithApplyDate.GateNo = GateCostRule.GateNo
			and
			FeeResultWithApplyDate.ApplyDate < GateCostRule.ApplyDate
	group by
		FeeResultWithApplyDate.GateNo,
		FeeResultWithApplyDate.MerchantNo,
		FeeResultWithApplyDate.FeeEndDate,
		FeeResultWithApplyDate.ApplyDate;


	--3.3 get TransWithRuleType
	insert into
		#GateMerRule
		(
			GateNo,
			MerchantNo,
			FeeEndDate,
			SucceedTransCount,
			SucceedTransAmount,
			FeeAmt,
			InstuFeeAmt,
			BankFeeAmt,
			CdFlag,
			Cost,
			CostRuleType,
			ApplyDate,
			NextApplyDate,
			SubCostRuleType,
			SubCostRuleValue
		)
	select
		FeeResult.GateNo,
		FeeResult.MerchantNo,
		FeeResult.FeeEndDate,
		FeeResult.PurCnt as SucceedTransCount,
		FeeResult.PurAmt as SucceedTransAmount,
		FeeResult.FeeAmt,
		FeeResult.InstuFeeAmt,
		FeeResult.BankFeeAmt,
		FeeResult.CdFlag,
		CONVERT(decimal(15,4),0) as Cost,
		isnull(GateCostRule.CostRuleType, '') as CostRuleType,
		isnull(FeeResultWithApplyDate.ApplyDate,'1900-01-01') as ApplyDate,
		case when 
			FeeResultWithApplyDate.NextApplyDate is null
			or FeeResultWithApplyDate.NextApplyDate > @EndDate
		then
			@EndDate
		else
			FeeResultWithApplyDate.NextApplyDate
		end as NextApplyDate,
		'' as SubCostRuleType,
		0 as SubCostRuleValue
	from
		#FeeResultWithAllApplyDate FeeResultWithApplyDate
		inner join
		#FeeResult FeeResult
		on
			FeeResultWithApplyDate.GateNo = FeeResult.GateNo
			and
			FeeResultWithApplyDate.MerchantNo = FeeResult.MerchantNo
			and
			FeeResultWithApplyDate.FeeEndDate = FeeResult.FeeEndDate
		left join
		Table_GateCostRule GateCostRule
		on
			FeeResultWithApplyDate.GateNo = GateCostRule.GateNo
			and
			FeeResultWithApplyDate.ApplyDate = GateCostRule.ApplyDate;
	
	--clear specific temp table		
	drop table #FeeResultWithApplyDate;
	drop table #FeeResultWithAllApplyDate;
end		
	
--4. calculate cost value

--4.1 calculate By Trans

--4.1.1 Fixed	
update
	GateMerRule
set
	GateMerRule.Cost = GateMerRule.SucceedTransCount * CostRuleByTrans.FeeValue
from
	#GateMerRule GateMerRule
	inner join
	Table_CostRuleByTrans CostRuleByTrans
	on
		GateMerRule.GateNo = CostRuleByTrans.GateNo
		and
		GateMerRule.ApplyDate = CostRuleByTrans.ApplyDate
where
	GateMerRule.CostRuleType = 'ByTrans'
	and
	CostRuleByTrans.FeeType = 'Fixed'
	and
	CostRuleByTrans.RefMaxAmt = @MaxRef
	and  
	CostRuleByTrans.RefMinAmt = @MinRef;

--4.1.2 Percent
update
	GateMerRule
set
	GateMerRule.Cost = GateMerRule.SucceedTransAmount * CostRuleByTrans.FeeValue
from
	#GateMerRule GateMerRule
	inner join
	Table_CostRuleByTrans CostRuleByTrans
	on
		GateMerRule.GateNo = CostRuleByTrans.GateNo
		and
		GateMerRule.ApplyDate = CostRuleByTrans.ApplyDate
where
	GateMerRule.CostRuleType = 'ByTrans'
	and
	CostRuleByTrans.FeeType = 'Percent'
	and
	CostRuleByTrans.RefMaxAmt = @MaxRef
	and  
	CostRuleByTrans.RefMinAmt = @MinRef;

--4.1.3 DetailGateNo  

--a.Get DetailPayment data
select
	FeeTransLog.GateNo,
	FeeTransLog.MerchantNo,
	FeeCalcResult.FeeEndDate,
	FeeTransLog.TransAmt	
into
	#TransDetail
from
	Table_FeeTransLog FeeTransLog
	inner join
	(select distinct 
			FeeBatchNo,
			FeeEndDate 
	from 
			Table_FeeCalcResult 
	where
			FeeEndDate >= @StartDate
			and
			FeeEndDate < @EndDate)FeeCalcResult
	on
		FeeTransLog.FeeBatchNo = FeeCalcResult.FeeBatchNo;	

--b.Cal DetailCost
With TransLogCost as
(
	select
		TransDetail.GateNo,
		TransDetail.MerchantNo,
		TransDetail.FeeEndDate,
		GateMerRule.ApplyDate,
		case when
			CostRuleByTrans.FeeType = 'Fixed'
		then
			CostRuleByTrans.FeeValue
		else
			TransDetail.TransAmt * CostRuleByTrans.FeeValue
		end DetailCost
	from	
		#TransDetail TransDetail
		inner join
		(select distinct
			GateNo,
			MerchantNo,
			ApplyDate,
			NextApplyDate,
			CostRuleType
		from
			#GateMerRule) GateMerRule
		on
			TransDetail.GateNo = GateMerRule.GateNo
			and
			TransDetail.MerchantNo = GateMerRule.MerchantNo
			and
			TransDetail.FeeEndDate >= GateMerRule.ApplyDate
			and
			TransDetail.FeeEndDate < GateMerRule.NextApplyDate
		inner join
		Table_CostRuleByTrans CostRuleByTrans
		on
			GateMerRule.GateNo = CostRuleByTrans.GateNo
			and
			GateMerRule.ApplyDate = CostRuleByTrans.ApplyDate
	where
		GateMerRule.CostRuleType = 'ByTrans'
		and
		(CostRuleByTrans.RefMaxAmt <> @MaxRef
		or
		CostRuleByTrans.RefMinAmt <> @MinRef)
		and
		(TransDetail.TransAmt >= CostRuleByTrans.RefMinAmt
		and
		TransDetail.TransAmt <  CostRuleByTrans.RefMaxAmt)
),
TransLogCostSum as
(
	select
		GateNo,
		MerchantNo,
		FeeEndDate,
		ApplyDate,
		SUM(DetailCost) as Cost
	from 
		TransLogCost
	group by
		GateNo,
		MerchantNo,
		FeeEndDate,
		ApplyDate
)
update 
	GateMerRule
set
	GateMerRule.Cost = TransLogCostSum.Cost
from
	#GateMerRule GateMerRule
	inner join
	TransLogCostSum 
	on
		GateMerRule.GateNo = TransLogCostSum.GateNo
		and
		GateMerRule.MerchantNo = TransLogCostSum.MerchantNo
		and
		GateMerRule.FeeEndDate = TransLogCostSum.FeeEndDate
		and
		GateMerRule.ApplyDate = TransLogCostSum.ApplyDate
where
	GateMerRule.CostRuleType = 'ByTrans';
	
--4.2 Caculate By Year
--Not consider RefMinAmt, RefMaxAmt

--4.2.1 Get Valid CostRuleByYearFixed
select
	GateNo,
	FeeValue/365 FeePerDay,
	ApplyDate,
	GateGroup
into
	#CostRuleByYearFixed
from
	Table_CostRuleByYear
where
	FeeType = 'Fixed'
	and
	RefMaxAmt = @MaxRef
	and
	RefMinAmt = @MinRef;

--4.2.2 Get GateGroup=0 CostRuleByYear
select
	GateNo,
	FeePerDay,
	ApplyDate
into
	#ByYearFixedSingleGate
from
	#CostRuleByYearFixed
where
	GateGroup = 0;

With SingleGateSumAmt as
(
	select
		GateNo,
		FeeEndDate,
		ApplyDate,
		--NextApplyDate,
		SucceedTransAmount
	from
		#GateMerRule
	where
		CostRuleType = 'ByYear'
),
SingleGateSumCost as 
(
	select
		SingleGateSumAmt.GateNo,
		SingleGateSumAmt.FeeEndDate,
		SingleGateSumAmt.ApplyDate,
		ByYearFixedSingleGate.FeePerDay as Cost,
		SingleGateSumAmt.SucceedTransAmount
	from
		#ByYearFixedSingleGate ByYearFixedSingleGate
		inner join
		SingleGateSumAmt
		on
			SingleGateSumAmt.GateNo = ByYearFixedSingleGate.GateNo
			and
			SingleGateSumAmt.ApplyDate = ByYearFixedSingleGate.ApplyDate
)
update
	GateMerRule
set
	GateMerRule.Cost = (case when
				SingleGateSumCost.SucceedTransAmount = 0
			then
				0
			else
				SingleGateSumCost.Cost
			end)
from
	#GateMerRule GateMerRule
	inner join
	SingleGateSumCost
	on
		GateMerRule.GateNo = SingleGateSumCost.GateNo
		and
		GateMerRule.FeeEndDate = SingleGateSumCost.FeeEndDate
		and
		GateMerRule.ApplyDate = SingleGateSumCost.ApplyDate
where
	GateMerRule.CostRuleType = 'ByYear';

--4.2.3 Get GateGroup<>0 CostRuleByYear
select
	GateNo,
	FeePerDay,
	ApplyDate,
	GateGroup
into
	#ByYearFixedGroupGate
from
	#CostRuleByYearFixed
where
	GateGroup <> 0;
	
With GroupGateSumAmt as
(
	select
		ByYearFixedGroupGate.GateGroup,
		GateMerRule.FeeEndDate,
		GateMerRule.ApplyDate,
		SUM(ISNULL(GateMerRule.SucceedTransAmount,0)) SucceedTransAmount
	from
		#GateMerRule GateMerRule
		inner join
		#ByYearFixedGroupGate ByYearFixedGroupGate
		on
			GateMerRule.GateNo = ByYearFixedGroupGate.GateNo
			and
			GateMerRule.ApplyDate = ByYearFixedGroupGate.ApplyDate
	where
		GateMerRule.CostRuleType = 'ByYear'
	group by
		ByYearFixedGroupGate.GateGroup,
		GateMerRule.FeeEndDate,
		GateMerRule.ApplyDate
),
GroupGateFee as
(
	select distinct
		GateGroup,
		FeePerDay,
		ApplyDate
	from
		#ByYearFixedGroupGate
),
GroupGateSumCost as 
(
	select
		GroupGateSumAmt.GateGroup,
		GroupGateSumAmt.FeeEndDate,
		GroupGateSumAmt.ApplyDate,
		GroupGateFee.FeePerDay as Cost,
		GroupGateSumAmt.SucceedTransAmount
	from
		GroupGateFee
		inner join
		GroupGateSumAmt
		on
			GroupGateFee.GateGroup = GroupGateSumAmt.GateGroup
			and
			GroupGateFee.ApplyDate = GroupGateSumAmt.ApplyDate
)
update
	GateMerRule
set
	GateMerRule.Cost = (case when
							GroupGateSumCost.SucceedTransAmount = 0
						then
							0
						else
							(CONVERT(decimal,GateMerRule.SucceedTransAmount)/GroupGateSumCost.SucceedTransAmount)*GroupGateSumCost.Cost
						end)
from
	#GateMerRule GateMerRule
	inner join
	#ByYearFixedGroupGate ByYearFixedGroupGate
	on
		GateMerRule.GateNo = ByYearFixedGroupGate.GateNo
		and
		GateMerRule.ApplyDate = ByYearFixedGroupGate.ApplyDate
	inner join
	GroupGateSumCost
	on
		GroupGateSumCost.GateGroup = ByYearFixedGroupGate.GateGroup
		and
		GroupGateSumCost.ApplyDate = ByYearFixedGroupGate.ApplyDate
		and
		GateMerRule.FeeEndDate = GroupGateSumCost.FeeEndDate
where
	GateMerRule.CostRuleType = 'ByYear';
	
--4.2.4 Calculate By Split
update 
	GateMerRule
set
	GateMerRule.cost = (
							case when
								ISNULL(GateMerRule.FeeAmt,0) <= ISNULL(GateMerRule.InstuFeeAmt,0)
							then
								0
							else	
								(GateMerRule.FeeAmt - ISNULL(GateMerRule.InstuFeeAmt,0)) * CostRuleByYear.FeeValue
							end
						)
from
	#GateMerRule GateMerRule
	inner join
	Table_CostRuleByYear CostRuleByYear
	on
		GateMerRule.GateNo = CostRuleByYear.GateNo
		and
		GateMerRule.ApplyDate = CostRuleByYear.ApplyDate
where
	CostRuleByYear.FeeType = N'Split'
	and
	CostRuleByYear.RefMaxAmt = @MaxRef
	and
	CostRuleByYear.RefMinAmt = @MinRef;
		
		
--4.3 Calculate by Merchant

--4.3.1 Calculate Cost for like cases
update
	GateMerRule
set
	GateMerRule.Cost = (case when 
							CostRuleByMer.FeeType = 'Percent'
						then
							CostRuleByMer.FeeValue * GateMerRule.SucceedTransAmount
						when
							CostRuleByMer.FeeType = 'Fixed'
						then
							CostRuleByMer.FeeValue * GateMerRule.SucceedTransCount
						else
							0
						end)	
from
	#GateMerRule GateMerRule
	inner join
	Table_CostRuleByMer CostRuleByMer
	on
		GateMerRule.GateNo = CostRuleByMer.GateNo
		and
		GateMerRule.MerchantNo like (RTRIM(CostRuleByMer.MerchantNo)+'%') 
		and
		GateMerRule.ApplyDate = CostRuleByMer.ApplyDate
where
	GateMerRule.CostRuleType = 'ByMer'
	and
	left(CostRuleByMer.MerchantNo,1) <> N'!';
	

--4.3.2 Calculate Cost for not like cases
update
	GateMerRule
set
	GateMerRule.Cost = (case when 
							CostRuleByMer.FeeType = 'Percent'
						then
							CostRuleByMer.FeeValue * GateMerRule.SucceedTransAmount
						when
							CostRuleByMer.FeeType = 'Fixed'
						then
							CostRuleByMer.FeeValue * GateMerRule.SucceedTransCount
						else
							0
						end)	
from
	#GateMerRule GateMerRule
	inner join
	Table_CostRuleByMer CostRuleByMer
	on
		GateMerRule.GateNo = CostRuleByMer.GateNo
		and
		GateMerRule.MerchantNo not like (ltrim(substring(CostRuleByMer.MerchantNo, 2, len(CostRuleByMer.MerchantNo)-1))+'%')
		and
		GateMerRule.ApplyDate = CostRuleByMer.ApplyDate
where
	GateMerRule.CostRuleType = 'ByMer'
	and
	left(CostRuleByMer.MerchantNo,1) = N'!';

--4.4 Calculate by Upop
--4.4.0 Create temp table #CostRuleByUpop
create table #CostRuleByUpop
(
	CostRuleType nvarchar(10),
	RuleObject varchar(15),
	FeeType varchar(15),
	FeeValue decimal(16,5),
	ApplyDate date,
	primary key (RuleObject, ApplyDate)
);

if @HisRefDate is not null
begin
	insert into #CostRuleByUpop
	(
		CostRuleType,
		RuleObject,
		FeeType,
		FeeValue,
		ApplyDate
	)
	select
		rule1.CostRuleType,
		rule1.RuleObject,
		rule1.FeeType,
		rule1.FeeValue,
		'1900-01-01' as ApplyDate
	from
		Table_UpopCostRule rule1
	where
		rule1.ApplyDate <= @HisRefDate
		and
		not exists(select 
						1 
					from 
						Table_UpopCostRule rule2 
					where 
						rule2.ApplyDate <= @HisRefDate 
						and 
						rule2.RuleObject = rule1.RuleObject 
						and 
						rule2.ApplyDate > rule1.ApplyDate)
end
else
begin
	insert into #CostRuleByUpop
	(
		CostRuleType,
		RuleObject,
		FeeType,
		FeeValue,
		ApplyDate
	)
	select
		CostRuleType,
		RuleObject,
		FeeType,
		FeeValue,
		ApplyDate	
	from
		Table_UpopCostRule
end

--4.4.1 Attach ByMer SubCostRuleType
update
	GateMerRule
set
	GateMerRule.SubCostRuleType = byMer.FeeType,
	GateMerRule.SubCostRuleValue = byMer.FeeValue
from
	#GateMerRule GateMerRule
	inner join
	Table_CupsMerInfo CpUpop
	on
		GateMerRule.MerchantNo = CpUpop.CpMerNo
		and
		GateMerRule.GateNo = CpUpop.GateNo
	cross apply
	(select top(1)
		FeeType,
		FeeValue
	from
		#CostRuleByUpop
	where
		CostRuleType = N'ByMer'
		and
		RuleObject = CpUpop.CupsMerNo
		and
		ApplyDate <= GateMerRule.FeeEndDate
	order by
		ApplyDate desc) byMer
where
	GateMerRule.CostRuleType = 'ByUpop'
	and
	GateMerRule.SubCostRuleType = '';
	
--4.4.2 Attach ByMcc SubCostRuleType
update
	GateMerRule
set
	GateMerRule.SubCostRuleType = byMcc.FeeType,
	GateMerRule.SubCostRuleValue = byMcc.FeeValue
from
	#GateMerRule GateMerRule
	inner join
	Table_CupsMerInfo CpUpop
	on
		GateMerRule.MerchantNo = CpUpop.CpMerNo
		and
		GateMerRule.GateNo = CpUpop.GateNo
	cross apply
	(select top(1)
		FeeType,
		FeeValue
	from
		#CostRuleByUpop
	where
		CostRuleType = N'ByMcc'
		and
		RuleObject = SUBSTRING(CpUpop.CupsMerNo,8,4)
		and
		ApplyDate <= GateMerRule.FeeEndDate
	order by
		ApplyDate desc) byMcc
where
	GateMerRule.CostRuleType = 'ByUpop'
	and
	GateMerRule.SubCostRuleType = '';

--4.4.3 Attach ByCd SubCostRuleType
update
	GateMerRule
set
	GateMerRule.SubCostRuleType = byCd.FeeType,
	GateMerRule.SubCostRuleValue = byCd.FeeValue
from
	#GateMerRule GateMerRule
	cross apply
	(select top(1)
		FeeType,
		FeeValue
	from
		#CostRuleByUpop
	where
		CostRuleType = N'ByCd'
		and
		RuleObject = GateMerRule.CdFlag
		and
		ApplyDate <= GateMerRule.FeeEndDate
	order by
		ApplyDate desc) byCd
where
	GateMerRule.CostRuleType = 'ByUpop'
	and
	GateMerRule.SubCostRuleType = '';

--4.4.4 Calculate byUpop Cost Value
update
	t
set
	t.Cost = case when t.SubCostRuleType = 'Fixed'
				then t.SucceedTransCount * t.SubCostRuleValue
				when t.SubCostRuleType = 'Percent'
				then t.SucceedTransAmount * t.SubCostRuleValue
				else 0 end
from
	#GateMerRule t
where
	t.CostRuleType = 'ByUpop';


--5. Get result
select 
	GateNo,
	MerchantNo,
	FeeEndDate,	
	SUM(ISNULL(SucceedTransCount,0)) TransCnt,
	SUM(ISNULL(SucceedTransAmount,0)) TransAmt,
	SUM(ISNULL(Cost,0)) as CostAmt,
	SUM(ISNULL(FeeAmt,0)) as FeeAmt,
	SUM(ISNULL(InstuFeeAmt,0)) InstuFeeAmt
from 
	#GateMerRule
group by
	GateNo,
	MerchantNo,
	FeeEndDate;	


--6. clear temp table 
drop table #FeeResult;
--drop table #FeeResultWithApplyDate;
--drop table #FeeResultWithAllApplyDate;
drop table #GateMerRule;
drop table #TransDetail;	
drop table #CostRuleByYearFixed;
drop table #ByYearFixedSingleGate;
drop table #ByYearFixedGroupGate;
drop table #CostRuleByUpop;

end