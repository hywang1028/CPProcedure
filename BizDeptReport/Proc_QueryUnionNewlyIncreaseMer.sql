--[Modified] at 2012-07-13 by 王红燕  Description:Add Financial Dept Configuration Data
if OBJECT_ID(N'Proc_QueryUnionNewlyIncreaseMer',N'P') is not null
begin
	drop procedure Proc_QueryUnionNewlyIncreaseMer;
end
go

Create Procedure Proc_QueryUnionNewlyIncreaseMer
	@StartDate datetime = '2011-01-12',
	@PeriodUnit nChar(3) = N'自定义',
	@EndDate datetime = '2011-04-12',
	@BranchOfficeName nChar(16) = N'中国银联股份有限公司安徽分公司'
as 
begin

--1. Check Input
if (@StartDate is null or ISNULL(@PeriodUnit,N'') = N'' or ISNULL(@BranchOfficeName,N'') = N'')
begin
	raiserror(N'Input params cannot be empty in Proc_QueryUnionNewlyIncreaseMer',16,1);
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
end


--3. Get Current Data
select
	MerchantName,
	MerchantNo
into
	#MerOpenAccountInfo
from
	Table_MerOpenAccountInfo
where
	OpenAccountDate >= @CurrStartDate
	and
	OpenAccountDate < @CurrEndDate;
	
	
--4.Get MerchantNo With BranchOffice
select
	SalesDeptConfiguration.MerchantNo,
	BranchOfficeNameRule.UnionPaySpec BranchOffice
into
	#MerWithBranch
from
	Table_SalesDeptConfiguration SalesDeptConfiguration
	inner join
	Table_BranchOfficeNameRule BranchOfficeNameRule
	on
		SalesDeptConfiguration.BranchOffice = BranchOfficeNameRule.UnnormalBranchOfficeName
where
	BranchOfficeNameRule.UnionPaySpec = @BranchOfficeName
union
select
	Finance.MerchantNo,
	BranchOfficeNameRule.UnionPaySpec BranchOffice
from
	Table_FinancialDeptConfiguration Finance
	inner join
	Table_BranchOfficeNameRule BranchOfficeNameRule
	on
		Finance.BranchOffice = BranchOfficeNameRule.UnnormalBranchOfficeName
where
	BranchOfficeNameRule.UnionPaySpec = @BranchOfficeName;
	
	
--5. Get NewlyIncreasedMerchantInfo
select
	MerOpenAccountInfo.MerchantName,
	MerOpenAccountInfo.MerchantNo
from
	#MerOpenAccountInfo MerOpenAccountInfo
	inner join
	#MerWithBranch MerWithBranch
	on
		MerOpenAccountInfo.MerchantNo = MerWithBranch.MerchantNo;
	
	
--6. drop temp table
drop table #MerOpenAccountInfo;
drop table #MerWithBranch;

end
	
	
	
	
