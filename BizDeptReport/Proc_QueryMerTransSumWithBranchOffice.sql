--[Modified] at 2012-07-13 by 王红燕  Description:Add Financial Dept Configuration Data
--[Modified] at 2012-12-13 by 王红燕  Description:Add Branch Office Fund Trans Data
--[Modified] at 2013-07-03 by 丁俊昊  Description:Add UpopliqFeeLiq_Data and TraScreenSum Data
if OBJECT_ID(N'Proc_QueryMerTransSumWithBranchOffice',N'P') is not null
begin
	drop procedure Proc_QueryMerTransSumWithBranchOffice;
end
go

Create Procedure Proc_QueryMerTransSumWithBranchOffice
	@StartDate datetime = '2012-11-01',
	@PeriodUnit nChar(5) = N'自定义',
	@EndDate datetime = '2012-11-29',
	@BranchOfficeName nChar(30) = N'银联商务有限公司四川分公司'
as
begin

--1. Check Input
if (@StartDate is null or ISNULL(@PeriodUnit,N'') = N'' or ISNULL(@BranchOfficeName,N'') = N'')
begin
	raiserror(N'Input params cannot be empty in Proc_QueryMerTransSumWithBranchOffice',16,1);
end

--2. Prepare StartDate and EndDate
declare @CurrStartDate datetime;
declare @CurrEndDate datetime;


if(@PeriodUnit = N'月')
begin
	set @CurrStartDate = left(CONVERT(char,@StartDate,120),7) + '-01';
	set @CurrEndDate = DATEADD(MONTH,1,@CurrStartDate);
end
else if(@PeriodUnit = N'季度')
begin
	set @CurrStartDate = left(CONVERT(char,@StartDate,120),7) + '-01';
	set @CurrEndDate = DATEADD(QUARTER,1,@CurrStartDate);
end
else if(@PeriodUnit = N'半年')
begin
	set @CurrStartDate = left(CONVERT(char,@StartDate,120),7) + '-01';
	set @CurrEndDate = DATEADD(QUARTER,2,@CurrStartDate);
end
else if(@PeriodUnit = N'自定义')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(DAY,1,@EndDate);
end;


--3.Get NewORA_Deduct_Data and Tra_Data
With ORATransData as
(
	select
		MerchantNo,
		SUM(TransCount) TransCnt,
		SUM(TransAmount) TransAmt
	from
		Table_OraTransSum
	where 
		CPDate >= @CurrStartDate
		and
		CPDate <  @CurrEndDate
	group by
		MerchantNo
	union all
	select
		MerchantNo,
		SUM(CalFeeCnt) TransCnt,
		SUM(CalFeeAmt) TransAmt		
	from
		Table_TraScreenSum
	where
		CPDate >= @CurrStartDate
		and
		CPDate <  @CurrEndDate
	group by 
		MerchantNo
),
WUTransData as
(
	select
		MerchantNo,
		(select MerchantName from Table_OraMerchants where MerchantNo = Table_WUTransLog.MerchantNo) MerchantName,
		COUNT(DestTransAmount) TransCnt,
		SUM(DestTransAmount) TransAmt
	from
		Table_WUTransLog
	where
		CPDate >= @CurrStartDate
		and
		CPDate <  @CurrEndDate
	group by
		MerchantNo
)
	select 
		ORATransData.MerchantNo,
		Coalesce(Table_OraMerchants.MerchantName,Table_TraMerchantInfo.MerchantName) MerchantName,
		SUM(TransCnt) TransCnt,
		SUM(TransAmt) TransAmt
	into
		#OraTransSum
	from 
		ORATransData
		left join
		Table_OraMerchants
		on
			ORATransData.MerchantNo = Table_OraMerchants.MerchantNo
		left join
		Table_TraMerchantInfo
		on
			ORATransData.MerchantNo = Table_TraMerchantInfo.MerchantNo
	group by
		ORATransData.MerchantNo,
		Coalesce(Table_OraMerchants.MerchantName,Table_TraMerchantInfo.MerchantName)
	union all
	select * from WUTransData;


with FactAndUPOP as
(
select 
	MerchantNo,
	'' UPOPMerchantNo,
	(select MerchantName from Table_MerInfo where MerchantNo = FactDailyTrans.MerchantNo) MerchantName,
	sum(SucceedTransCount) SucceedTransCount,
	sum(SucceedTransAmount) SucceedTransAmount
from
	FactDailyTrans
where
	DailyTransDate >= @CurrStartDate
	and
	DailyTransDate < @CurrEndDate
group by
	MerchantNo
union all	
select
	case when
		UPOP.MerchantNo = CPRelation.UpopMerNo
	then
		CPRelation.CpMerNo
	else
		UPOP.MerchantNo
	end
		as MerchantNo,
	UPOP.MerchantNo as UPOPMerchantNo,
	UPOPMer.MerchantName,
	SUM(PurCnt) TransCnt,
	SUM(PurAmt) TransAmt
from
	Table_UpopliqFeeLiqResult UPOP
	left join
	Table_CpUpopRelation CPRelation
	on
		UPOP.MerchantNo = CPRelation.UpopMerNo
	left join
	Table_UpopliqMerInfo UPOPMer
	on
		UPOP.MerchantNo = UPOPMer.MerchantNo
where
	TransDate >= @CurrStartDate
	and
	TransDate < @CurrEndDate
group by
	UPOP.MerchantNo,
	CPRelation.CpMerNo,
	CPRelation.UpopMerNo,
	UPOPMEr.MerchantName
)
	select
		MerchantNo,
		UPOPMerchantNo,
		MerchantName,
		SUM(SucceedTransCount) SucceedTransCount,
		SUM(SucceedTransAmount) SucceedTransAmount
	into
		#FactDailyTrans
	from
		FactAndUPOP
	group by
		MerchantNo,
		UPOPMerchantNo,
		MerchantName;


select 
	EmallTransSum.MerchantNo,
	'' as UPOPMerchantNo,
	EmallTransSum.MerchantName,
	sum(EmallTransSum.SucceedTransCount) TransCount,
	sum(EmallTransSum.SucceedTransAmount) TransAmount
into 
	#EmallTransSum
from	
	Table_EmallTransSum EmallTransSum
	inner join
	Table_BranchOfficeNameRule BranchOfficeNameRule
	on
		EmallTransSum.BranchOffice = BranchOfficeNameRule.UnnormalBranchOfficeName
where 
	EmallTransSum.TransDate >= @CurrStartDate
	and
	EmallTransSum.TransDate < @CurrEndDate
	and
	BranchOfficeNameRule.UmsSpec = @BranchOfficeName
group by
	EmallTransSum.MerchantNo,
	EmallTransSum.MerchantName;


--Add Branch Office Fund Trans Data
select 
	N'' as MerchantNo,
	'' as UPOPMerchantNo,
	N'基金' as MerchantName,
	SUM(Branch.B2BPurchaseCnt+Branch.B2BRedemptoryCnt+Branch.B2CPurchaseCnt+Branch.B2CRedemptoryCnt) TransCount,
	SUM(Branch.B2BPurchaseAmt+Branch.B2BRedemptoryAmt+Branch.B2CPurchaseAmt+Branch.B2CRedemptoryAmt) TransAmount
into
	#BranchFundTrans
from 
	Table_UMSBranchFundTrans Branch
	inner join
	Table_BranchOfficeNameRule BranchOfficeNameRule
	on
		Branch.BranchOfficeName = BranchOfficeNameRule.UnnormalBranchOfficeName
where	
	Branch.TransDate >= @CurrStartDate
	and
	Branch.TransDate <  @CurrEndDate
	and
	BranchOfficeNameRule.NormalBranchOfficeName = @BranchOfficeName;


--4. Get table MerWithBranchOffice
select
	SalesDeptConfiguration.MerchantNo
into
	#MerWithBranchOffice
from
	Table_BranchOfficeNameRule BranchOfficeNameRule 
	inner join
	Table_SalesDeptConfiguration SalesDeptConfiguration
	on
		BranchOfficeNameRule.UnnormalBranchOfficeName = SalesDeptConfiguration.BranchOffice
where 
	BranchOfficeNameRule.UmsSpec = @BranchOfficeName
union 
select
	Finance.MerchantNo
from
	Table_BranchOfficeNameRule BranchOfficeNameRule 
	inner join
	Table_FinancialDeptConfiguration Finance
	on
		BranchOfficeNameRule.UnnormalBranchOfficeName = Finance.BranchOffice
where	BranchOfficeNameRule.UmsSpec = @BranchOfficeName;


--5. Get TransDetail respectively
select
	OraTransSum.MerchantName,
	OraTransSum.MerchantNo,
	'' as UPOPMerchantNo,
	OraTransSum.TransCnt,
	OraTransSum.TransAmt
into
	#OraTransWithBO
from
	#OraTransSum OraTransSum
	inner join
	#MerWithBranchOffice MerWithBranchOffice
	on
		OraTransSum.MerchantNo = MerWithBranchOffice.MerchantNo;

select
	FactDailyTrans.MerchantName,
	FactDailyTrans.MerchantNo,
	FactDailyTrans.UPOPMerchantNo,
	FactDailyTrans.SucceedTransCount as TransCount,
	FactDailyTrans.SucceedTransAmount as TransAmount
into
	#FactDailyTransWithBO
from
	#FactDailyTrans FactDailyTrans
	inner join
	#MerWithBranchOffice MerWithBranchOffice
	on
		FactDailyTrans.MerchantNo = MerWithBranchOffice.MerchantNo;

	
--6. Union all Trans
select
	MerchantName,
	MerchantNo,
	UPOPMerchantNo,
	ISNULL(TransCnt,0) TransCount,
	convert(decimal, ISNULL(TransAmt,0))/100.0 TransAmount
into
	#AllTransSum
from
	(select
		MerchantName,
		MerchantNo,
		UPOPMerchantNo,
		TransCnt,
		TransAmt
	from
		#OraTransWithBO
	union all
	select 
		MerchantName,
		MerchantNo,
		UPOPMerchantNo,
		TransCount,
		TransAmount
	from
		#FactDailyTransWithBO
	union all
	select
		MerchantName,
		MerchantNo,
		UPOPMerchantNo,
		TransCount,
		TransAmount
	from
		#EmallTransSum
	union all 
	select
		MerchantName,
		MerchantNo,
		UPOPMerchantNo,
		TransCount,
		TransAmount
	from
		#BranchFundTrans) Mer;


--7. Get Special MerchantNo
select 
	SalesDeptConfiguration.MerchantNo
into
	#SpecMerchantNo
from
	Table_SalesDeptConfiguration SalesDeptConfiguration
	inner join
	Table_BranchOfficeNameRule BranchOfficeNameRule
	on
		SalesDeptConfiguration.BranchOffice = BranchOfficeNameRule.UnnormalBranchOfficeName
where
	BranchOfficeNameRule.UmsSpecMark = 1
union
select
	Finance.MerchantNo
from
	Table_FinancialDeptConfiguration Finance
	inner join
	Table_BranchOfficeNameRule BranchOfficeNameRule
	on
		Finance.BranchOffice = BranchOfficeNameRule.UnnormalBranchOfficeName
where
	BranchOfficeNameRule.UmsSpecMark = 1;
	

--8. Get Result	
update
	AllTransSum
set
	AllTransSum.MerchantName = ('*'+AllTransSum.MerchantName)
from
	#AllTransSum AllTransSum
	inner join
	#SpecMerchantNo SpecMerchantNo
	on
		AllTransSum.MerchantNo = SpecMerchantNo.MerchantNo;


-- Get UPOPMer
with UPOP as
(
	select distinct MerchantNo from Table_UpopliqFeeLiqResult
)
	select
		MerchantName,
		case when
			UPOPMerchantNo = UPOP.MerchantNo
		then
			UPOPMerchantNo
		else
			#AllTransSum.MerchantNo
		end
			as MerchantNo,
		TransCount,
		TransAmount
	into
		#Result
	from	
		#AllTransSum
		left join
		UPOP
		on
			#AllTransSum.UPOPMerchantNo = UPOP.MerchantNo;


-- 根据用户要求进行排序
with Finaly as
(
	select  
		MerchantName,  
	case when  
		substring(MerchantNo,1,1) = '6'  
	then  
		1  
	when  
		substring(MerchantNo,1,3) = '808'  
	then  
		2  
	when  
		substring(MerchantNo,1,3) = '802'  
	then  
		3  
	when  
		MerchantNo = ''  
	then  
		5  
	else  
		4  
	end ID,  
		MerchantNo,  
		TransCount,  
		TransAmount  
	from  
		#Result  
)
	select
		MerchantName,
		ID,
		MerchantNo,
		SUM(TransCount) TransCount,
		SUM(TransAmount) TransAmount
	from 
		Finaly
	group by 
		MerchantName,
		ID,
		MerchantNo
	order by  
		ID;
  


--9. drop temp table
drop table #Result;
drop table #OraTransSum;
drop table #FactDailyTrans;
drop table #EmallTransSum;
drop table #MerWithBranchOffice;
drop table #OraTransWithBO;
drop table #FactDailyTransWithBO;
drop table #AllTransSum;
drop table #SpecMerchantNo;
drop table #BranchFundTrans;

end

