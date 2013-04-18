--[Modified] at 2012-07-13 by 王红燕  Description:Add Financial Dept Configuration Data
--[Modified] at 2012-12-13 by 王红燕  Description:Add Branch Office Fund Trans Data
if OBJECT_ID(N'Proc_QueryBranchOfficeSummarize',N'P') is not null
begin
	drop procedure Proc_QueryBranchOfficeSummarize;
end
go

create procedure Proc_QueryBranchOfficeSummarize
	@StartDate datetime = '2012-11-01',
	@EndDate datetime = '2012-11-12',
	@PeriodUnit nChar(3) = N'自定义'
as 
begin

--1. Check Input
if (@StartDate is null or ISNULL(@PeriodUnit,N'') = N'' or (@PeriodUnit = N'自定义' and @EndDate is null))
begin
	raiserror('Input parameters can`t be empty in Proc_QueryBranchOfficeSummarize!',16,1);
end


--2. Prepare StartDate and EndDate
declare @CurrStartDate datetime;
declare @CurrEndDate datetime;

if (@PeriodUnit = N'月')
begin
	set @CurrStartDate = LEFT(CONVERT(char,@StartDate,120),7) + '-01';
	set @CurrEndDate = DATEADD(month,1,@CurrStartDate);
end
else if(@PeriodUnit = N'季度')
begin
	set @CurrStartDate = LEFT(CONVERT(char,@StartDate,120),7) + '-01';
	set @CurrEndDate = DATEADD(QUARTER,1,@CurrStartDate);
end
else if(@PeriodUnit = N'半年')
begin
	set @CurrStartDate = LEFT(CONVERT(char,@StartDate,120),7) + '-01';
	set @CurrEndDate = DATEADD(QUARTER,2,@CurrStartDate);
end
else if(@PeriodUnit = N'自定义')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(DAY,1,@EndDate);
end


--3.Get Corresponding CurrentData
select
	MerchantNo,
	SUM(ISNULL(TransCount,0)) TransCount,
	SUM(ISNULL(TransAmount,0)) TransAmount
into
	#OraTransSum
from	
	Table_OraTransSum
where
	CPDate >= @CurrStartDate
	and
	CPDate < @CurrEndDate
group by	
	MerchantNo;

select
	MerchantNo,
	SUM(ISNULL(SucceedTransCount,0)) TransCount,
	SUM(ISNULL(SucceedTransAmount,0)) TransAmount
into
	#FactDailyTrans
from
	FactDailyTrans
where 
	DailyTransDate >= @CurrStartDate
	and
	DailyTransDate < @CurrEndDate
group by
	MerchantNo;
	
select
	EmallTransSum.MerchantNo,
	BranchOfficeNameRule.UmsSpec BranchOffice,
	SUM(ISNULL(EmallTransSum.SucceedTransCount,0)) TransCount,
	SUM(ISNULL(EmallTransSum.SucceedTransAmount,0)) TransAmount
into
	#EmallTransSum
from
	Table_EmallTransSum EmallTransSum
	inner join
	Table_BranchOfficeNameRule BranchOfficeNameRule
	on
		EmallTransSum.BranchOffice = BranchOfficeNameRule.UnnormalBranchOfficeName
		and
		ISNULL(BranchOfficeNameRule.UmsSpec,N'') <> N''
where
	TransDate >= @CurrStartDate
	and
	TransDate < @CurrEndDate
group by
	EmallTransSum.MerchantNo,
	BranchOfficeNameRule.UmsSpec;
	
select
	MerchantNo
into
	#NewlyOpenMer
from
	Table_MerOpenAccountInfo
where
	OpenAccountDate >= @CurrStartDate
	and
	OpenAccountDate < @CurrEndDate;


--4.Get MerchantNoWithBranchOffice 
With SalesBranchOffice as
(
	select
		SalesDeptConfig.MerchantNo,
		BranchOfficeNameRule.UmsSpec BranchOffice
	from
		Table_SalesDeptConfiguration SalesDeptConfig
		inner join
		Table_BranchOfficeNameRule BranchOfficeNameRule
		on
			SalesDeptConfig.BranchOffice = BranchOfficeNameRule.UnnormalBranchOfficeName
			and
			ISNULL(BranchOfficeNameRule.UmsSpec,N'') <> N''
),
FinanceBranchOffice as 
(
	select
		Finance.MerchantNo,
		BranchOfficeNameRule.UmsSpec BranchOffice
	from
		Table_FinancialDeptConfiguration Finance
		inner join
		Table_BranchOfficeNameRule BranchOfficeNameRule
		on
			Finance.BranchOffice = BranchOfficeNameRule.UnnormalBranchOfficeName
			and
			ISNULL(BranchOfficeNameRule.UmsSpec,N'') <> N''
)
select 
	coalesce(SalesBranchOffice.MerchantNo, FinanceBranchOffice.MerchantNo) MerchantNo,
	coalesce(SalesBranchOffice.BranchOffice, FinanceBranchOffice.BranchOffice) BranchOffice
into
	#MerWithBranch
from
	SalesBranchOffice
	full outer join 
	FinanceBranchOffice
	on
		SalesBranchOffice.MerchantNo = FinanceBranchOffice.MerchantNo;


--5. Get Respectively BranchOffice
select
	MerWithBranch.BranchOffice,
	MerWithBranch.MerchantNo,
	ISNULL(OraTransSum.TransCount,0)+ISNULL(FactDailyTrans.TransCount,0) TransCount,
	ISNULL(OraTransSum.TransAmount,0)+ISNULL(FactDailyTrans.TransAmount,0) TransAmount
into
	#OraAndDailyWithBranch
from
	#MerWithBranch MerWithBranch
	left join
	#OraTransSum OraTransSum
	on
		MerWithBranch.MerchantNo = OraTransSum.MerchantNo
	left join
	#FactDailyTrans FactDailyTrans
	on
		MerWithBranch.MerchantNo = FactDailyTrans.MerchantNo;


--6. Union All Data
select
	BranchOffice,
	MerchantNo,
	TransCount,
	TransAmount
into
	#AllMerWithBranch
from
	#OraAndDailyWithBranch
union all
select
	BranchOffice,
	MerchantNo,
	TransCount,
	TransAmount
from	
	#EmallTransSum;

--Add Branch Office Fund Trans Data
select 
	BranchOfficeNameRule.NormalBranchOfficeName BranchOffice,
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
group by
	BranchOfficeNameRule.NormalBranchOfficeName;

--7. Get Result
With TempResult as
(
	select
		AllMerWithBranch.BranchOffice,
		COUNT(NewlyOpenMer.MerchantNo) NewlyIncreMerCount,
		SUM(ISNULL(AllMerWithBranch.TransCount,0)) SumTransCount,
		SUM(ISNULL(AllMerWithBranch.TransAmount,0)) SumTransAmount
	from
		#AllMerWithBranch AllMerWithBranch
		left join
		#NewlyOpenMer NewlyOpenMer
		on
			AllMerWithBranch.MerchantNo = NewlyOpenMer.MerchantNo
	group by
		AllMerWithBranch.BranchOffice
)
select
	TempResult.BranchOffice,
	TempResult.NewlyIncreMerCount,
	CONVERT(decimal,TempResult.SumTransCount)/10000 SumTransCount,
	CONVERT(decimal,TempResult.SumTransAmount)/1000000 SumTransAmount,
	CONVERT(decimal,ISNULL(BranchFundTrans.TransCount,0))/10000 SumFundCount,
	CONVERT(decimal,ISNULL(BranchFundTrans.TransAmount,0))/1000000 SumFundAmount
into 
	#Result
from
	TempResult
	left join
	#BranchFundTrans BranchFundTrans
	on
		TempResult.BranchOffice = BranchFundTrans.BranchOffice;

With #Sum as
(
	select 
		SUM(SumTransAmount) WholeSum
	from 
		#Result
)
select
	R.BranchOffice,
	R.NewlyIncreMerCount,
	R.SumTransCount,
	R.SumTransAmount,
	R.SumFundCount,
	R.SumFundAmount,
	case when 
		S.WholeSum = 0
	then
		0
	else
	CONVERT(decimal,ISNULL(R.SumTransAmount,0)) / S.WholeSum 
	end Ratio,
	case when 
		R.BranchOffice = N'北京数字王府井科技有限公司'
	then
		N'数字王府井'
	when
		R.BranchOffice = N'北京银联商务有限公司'
	then
		N'北京'
	when
		R.BranchOffice = N'广州银联网络支付有限公司'
	then 
		N'好易联'
	when
		R.BranchOffice = N'银联商务有限公司黑龙江分公司'
	then
		N'黑龙江'
	when
		R.BranchOffice = N'银联商务有限公司内蒙古分公司'
	then
		N'内蒙古'
	else
		SUBSTRING(R.BranchOffice,9,2)
	end Area
from
	#Result R,
	#Sum S
order by
	R.SumTransAmount desc;


--8. Drop Temp Tables
drop table #OraTransSum;
drop table #FactDailyTrans;
drop table #EmallTransSum;
drop table #NewlyOpenMer;
drop table #MerWithBranch;
drop table #OraAndDailyWithBranch;
drop table #AllMerWithBranch;
drop table #Result;
drop table #BranchFundTrans;

end