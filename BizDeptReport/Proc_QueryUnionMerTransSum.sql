--[Modified] at 2012-07-13 by 王红燕  Description:Add Financial Dept Configuration Data
--[Modified] at 2013-07-12 by 丁俊昊  Description:Add UPOP Data And TraScreenSum Data
if OBJECT_ID(N'Proc_QueryUnionMerTransSum',N'P') is not null
begin
	drop procedure Proc_QueryUnionMerTransSum;
end
go

Create Procedure Proc_QueryUnionMerTransSum
	@StartDate datetime = '2011-06-12',
	@PeriodUnit nChar(3) = N'自定义',
	@EndDate datetime = '2011-09-12',
	@BranchOfficeName nChar(20) = N'中国银联股份有限公司辽宁分公司'
as 
begin

--1. Check Input
if (@StartDate is null or ISNULL(@PeriodUnit,N'') = N'' or ISNULL(@BranchOfficeName,N'') = N'')
begin
	raiserror(N'Input params cannot be empty in Proc_QueryUnionMerTransSum',16,1);
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
	set @CurrEndDate =   DATEADD(DAY,1,@EndDate);
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
	
	
With ValidPayData as
(
	select 
		Trans.MerchantNo MerchantNo,
		SUM(Trans.SucceedTransCount) as TransCnt,
		SUM(Trans.SucceedTransAmount) as TransAmt
	from
		FactDailyTrans Trans
	where
		Trans.DailyTransDate >= @CurrStartDate
		and
		Trans.DailyTransDate < @CurrEndDate
	group by
		Trans.MerchantNo
),
InvalidPayData as
(
	select 
		Trans.DailyTransLog_MerchantNo MerchantNo,
		SUM(Trans.DailyTransLog_SucceedTransCount) as TransCnt,
		SUM(Trans.DailyTransLog_SucceedTransAmount) as TransAmt
	from
		Table_InvalidDailyTrans Trans
	where
		Trans.DailyTransLog_Date >= @CurrStartDate
		and
		Trans.DailyTransLog_Date < @CurrEndDate
	group by
		Trans.DailyTransLog_MerchantNo
),
FactDailyTrans as
(
select
	coalesce(Data.MerchantNo,Invalid.MerchantNo) MerchantNo,
	ISNULL(Data.TransCnt,0)+ISNULL(Invalid.TransCnt,0) TransCnt,
	ISNULL(Data.TransAmt,0)+ISNULL(Invalid.TransAmt,0) TransAmt
from
	ValidPayData Data
	full outer join
	InvalidPayData Invalid
	on
		Data.MerchantNo = Invalid.MerchantNo
where
	coalesce(Data.MerchantNo,Invalid.MerchantNo)not in ('808080290000007')
)
select
	case when
		UPOP.MerchantNo = CPRelation.UpopMerNo
	then
		CPRelation.CpMerNo
	else
		UPOP.MerchantNo
	end
		as MerchantNo,
	Table_UpopliqMerInfo.MerchantName,
	SUM(PurCnt) TransCnt,
	SUM(PurAmt) TransAmt
into
	#FactDailyTransAndUPOP
from
	Table_UpopliqFeeLiqResult UPOP
	left join
	Table_UpopliqMerInfo
	on
		UPOP.MerchantNo = Table_UpopliqMerInfo.MerchantNo
	left join
	Table_CpUpopRelation  CPRelation
	on
		UPOP.MerchantNo = CPRelation.UpopMerNo
where
	TransDate >= @CurrStartDate
	and
	TransDate < @CurrEndDate
group by
	UPOP.MerchantNo,
	Table_UpopliqMerInfo.MerchantName,CPRelation.UpopMerNo,CPRelation.CpMerNo
union all
select
	FactDailyTrans.MerchantNo,
	Table_MerInfo.MerchantName,
	TransCnt,
	TransAmt
from
	FactDailyTrans
	left join 
	Table_MerInfo
	on
		FactDailyTrans.MerchantNo = Table_MerInfo.MerchantNo;
		


--4. Get table Merchant With BranchOffice
select
	SalesDeptConfiguration.MerchantNo
into
	#MerWithBranchOffice
from
	Table_BranchOfficeNameRule BranchOfficeNameRule 
	inner join
	Table_SalesDeptConfiguration SalesDeptConfiguration
	on
		SalesDeptConfiguration.BranchOffice = BranchOfficeNameRule.UnnormalBranchOfficeName
		and
		ISNULL(BranchOfficeNameRule.NormalBranchOfficeName,N'') <> N''
where
	BranchOfficeNameRule.NormalBranchOfficeName = @BranchOfficeName
union
select
	Finance.MerchantNo
from
	Table_BranchOfficeNameRule BranchOfficeNameRule 
	inner join
	Table_FinancialDeptConfiguration Finance
	on
		Finance.BranchOffice = BranchOfficeNameRule.UnnormalBranchOfficeName
		and
		ISNULL(BranchOfficeNameRule.NormalBranchOfficeName,N'') <> N''
where
	BranchOfficeNameRule.NormalBranchOfficeName = @BranchOfficeName;

	
--5. Get TransDetail respectively
select
	OraTransSum.MerchantName,
	OraTransSum.MerchantNo,
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
	FactDailyTrans.TransCnt as TransCount,
	FactDailyTrans.TransAmt as TransAmount
into
	#FactDailyTransWithBO
from
	#FactDailyTransAndUPOP FactDailyTrans
	inner join
	#MerWithBranchOffice MerWithBranchOffice
	on
		FactDailyTrans.MerchantNo = MerWithBranchOffice.MerchantNo;


--5. Union all Trans
select
	MerchantName,
	MerchantNo,
	TransCnt,
	convert(decimal, TransAmt)/100.0 TransAmt
into
	#TempResult
from
	(select
		MerchantName,
		MerchantNo,
		TransCnt,
		TransAmt
	from
		#OraTransWithBO	
	union all
	select 
		MerchantName,
		MerchantNo,
		TransCount as TransCnt,
		TransAmount as TransAmt
	from
		#FactDailyTransWithBO	
	) Mer;


update 
	#TempResult
set
	#TempResult.MerchantNo = Table_CpUpopRelation.UpopMerNo
from
	#TempResult
	inner join
	Table_CpUpopRelation
	on
		#TempResult.MerchantNo = Table_CpUpopRelation.CpMerNo
where
	#TempResult.MerchantNo = Table_CpUpopRelation.CpMerNo;


select
	*
from
	#TempResult



--6. drop temp table
drop table #OraTransSum;
drop table #FactDailyTransAndUPOP;
drop table #OraTransWithBO;
drop table #FactDailyTransWithBO;
drop table #TempResult;

end

