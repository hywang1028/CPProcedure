--[Modified] at 2012-07-13 by 王红燕  Description:Add Financial Dept Configuration Data
if OBJECT_ID(N'Proc_QueryNewlyIncreasedMerWithBranchOffice',N'P') is not null
begin
	drop procedure Proc_QueryNewlyIncreasedMerWithBranchOffice;
end
go

Create Procedure Proc_QueryNewlyIncreasedMerWithBranchOffice
	@StartDate datetime = '2012-10-22',
	@PeriodUnit nChar(3) = N'月',
	@EndDate datetime = '2012-12-30',
	@BranchOfficeName nChar(15) = N'银联商务有限公司安徽分公司'
as 
begin

--1. Check Input
if (@StartDate is null or ISNULL(@PeriodUnit,N'') = N'' or ISNULL(@BranchOfficeName,N'') = N'')
begin
	raiserror(N'Input params cannot be empty in Proc_QueryNewlyIncreasedMerWithBranchOffice',16,1);
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
	

--4. Get table MerWithBranchOffice
With SalesBranchOffice as
(
	select
		SalesDeptConfig.MerchantNo,
		BranchOfficeNameRule.UmsSpecMark UmsSpecMark
	from
		Table_SalesDeptConfiguration SalesDeptConfig
		inner join
		Table_BranchOfficeNameRule BranchOfficeNameRule
		on
			SalesDeptConfig.BranchOffice = BranchOfficeNameRule.UnnormalBranchOfficeName
			and
			ISNULL(BranchOfficeNameRule.UmsSpec,N'') <> N''
	where
		BranchOfficeNameRule.UmsSpec = @BranchOfficeName
),
FinanceBranchOffice as 
(
	select
		Finance.MerchantNo,
		BranchOfficeNameRule.UmsSpecMark UmsSpecMark
	from
		Table_FinancialDeptConfiguration Finance
		inner join
		Table_BranchOfficeNameRule BranchOfficeNameRule
		on
			Finance.BranchOffice = BranchOfficeNameRule.UnnormalBranchOfficeName
			and
			ISNULL(BranchOfficeNameRule.UmsSpec,N'') <> N''
	where
		BranchOfficeNameRule.UmsSpec = @BranchOfficeName
)
select 
	coalesce(SalesBranchOffice.MerchantNo, FinanceBranchOffice.MerchantNo) MerchantNo,
	coalesce(SalesBranchOffice.UmsSpecMark, FinanceBranchOffice.UmsSpecMark) UmsSpecMark
into
	#MerWithBranchOffice
from
	SalesBranchOffice
	full outer join 
	FinanceBranchOffice
	on
		SalesBranchOffice.MerchantNo = FinanceBranchOffice.MerchantNo;
	
	
--5. Get Newly Increased Merchant & Special Merchant
select
	case when 
			MerWithBranchOffice.UmsSpecMark = 1
		 then
			'*'+MerOpenAccountInfo.MerchantName
		 else
			MerOpenAccountInfo.MerchantName
		 end MerchantName,
	MerOpenAccountInfo.MerchantNo
from
	#MerOpenAccountInfo MerOpenAccountInfo
	inner join
	#MerWithBranchOffice MerWithBranchOffice
	on
		MerOpenAccountInfo.MerchantNo = MerWithBranchOffice.MerchantNo;

	
--6. drop temp table
drop table #MerOpenAccountInfo;
drop table #MerWithBranchOffice;

end
	
	
	
	
