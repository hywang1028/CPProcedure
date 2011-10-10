if OBJECT_ID(N'Proc_QueryNewlyIncreasedMerWithBranchOffice',N'P') is not null
begin
	drop procedure Proc_QueryNewlyIncreasedMerWithBranchOffice;
end
go

Create Procedure Proc_QueryNewlyIncreasedMerWithBranchOffice
	@StartDate datetime = '2010-01-12',
	@PeriodUnit nChar(3) = N'自定义',
	@EndDate datetime = '2011-09-05',
	@BranchOfficeName nChar(15) = N'银联商务有限公司四川分公司'
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
	set @CurrStartDate = left(CONVERT(char,@StartDate,120),7) + '-01';
	set @CurrEndDate =   DATEADD(MONTH,1,left(CONVERT(char,@EndDate,120),7) + '-01');
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
select
	SalesDeptConfiguration.MerchantNo
into
	#MerWithBranchOffice
from
	Table_SalesDeptConfiguration SalesDeptConfiguration
	inner join
	Table_BranchOfficeNameMapping BranchOfficeNameMapping
	on
		SalesDeptConfiguration.BranchOffice = BranchOfficeNameMapping.OrigBranchOffice
where
	BranchOfficeNameMapping.DestBranchOffice = @BranchOfficeName;
	
	
	
--5. Get NewlyIncreasedMerWithBranchOffice
select
	MerOpenAccountInfo.MerchantName,
	MerOpenAccountInfo.MerchantNo
into
	#NewlyIncreasedMer
from
	#MerOpenAccountInfo MerOpenAccountInfo
	inner join
	#MerWithBranchOffice MerWithBranchOffice
	on
		MerOpenAccountInfo.MerchantNo = MerWithBranchOffice.MerchantNo;
	

--6. Get Special MerchantNo
select 
	MerchantNo
into
	#SpecMerchantNo
from
	Table_SalesDeptConfiguration
where
	BranchOffice in (N'中国银联股份有限公司重庆分公司',N'中国银联股份有限公司湖南分公司',N'中国银联股份有限公司宁波分公司',N'中国银联股份有限公司四川分公司');
	

--7. Get Result	
update
	NewlyIncreasedMer
set
	NewlyIncreasedMer.MerchantName = ('*'+NewlyIncreasedMer.MerchantName)
from
	#NewlyIncreasedMer NewlyIncreasedMer 
	inner join
	#SpecMerchantNo SpecMerchantNo
	on
		NewlyIncreasedMer.MerchantNo = SpecMerchantNo.MerchantNo;

select
	MerchantName,
	MerchantNo
from	
	#NewlyIncreasedMer;	
	
--8. drop temp table
drop table #MerOpenAccountInfo;
drop table #MerWithBranchOffice;
drop table #NewlyIncreasedMer;
drop table #SpecMerchantNo;
end
	
	
	
	
