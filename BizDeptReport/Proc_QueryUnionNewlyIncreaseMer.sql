if OBJECT_ID(N'Proc_QueryUnionNewlyIncreaseMer',N'P') is not null
begin
	drop procedure Proc_QueryUnionNewlyIncreaseMer;
end
go

Create Procedure Proc_QueryUnionNewlyIncreaseMer
	@StartDate datetime = '2011-03-12',
	@PeriodUnit nChar(3) = N'月',
	@BranchOfficeName nChar(16) = N'中国银联股份有限公司内蒙古分公司'
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
	
	
--4. Get NewlyIncreasedMerchantInfo
select
	MerOpenAccountInfo.MerchantName,
	MerOpenAccountInfo.MerchantNo
from
	#MerOpenAccountInfo MerOpenAccountInfo
	inner join
	Table_SalesDeptConfiguration SalesDeptConfig
	on
		MerOpenAccountInfo.MerchantNo = SalesDeptConfig.MerchantNo
where
	SalesDeptConfig.BranchOffice = @BranchOfficeName;
	
	
--5. drop temp table
drop table #MerOpenAccountInfo;

end
	
	
	
	
