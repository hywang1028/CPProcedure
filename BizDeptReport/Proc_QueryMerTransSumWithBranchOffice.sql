if OBJECT_ID(N'Proc_QueryMerTransSumWithBranchOffice',N'P') is not null
begin
	drop procedure Proc_QueryMerTransSumWithBranchOffice;
end
go

Create Procedure Proc_QueryMerTransSumWithBranchOffice
	@StartDate datetime = '2012-02-01',
	@PeriodUnit nChar(3) = N'自定义',
	@EndDate datetime = '2012-02-31',
	@BranchOfficeName nChar(15) = N'银联商务有限公司四川分公司'
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
end


--3.Get SpecifiedTimePeriod Data
select
	MerchantNo,
	sum(TransCount) TransCount,
	sum(TransAmount) TransAmount
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
	sum(SucceedTransCount) SucceedTransCount,
	sum(SucceedTransAmount) SucceedTransAmount
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


--4. Get table MerWithBranchOffice
select
	SalesDeptConfiguration.MerchantName,
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
	BranchOfficeNameRule.UmsSpec = @BranchOfficeName;


--5. Get TransDetail respectively
select
	MerWithBranchOffice.MerchantName,
	OraTransSum.MerchantNo,
	OraTransSum.TransCount,
	OraTransSum.TransAmount
into
	#OraTransWithBO
from
	#OraTransSum OraTransSum
	inner join
	#MerWithBranchOffice MerWithBranchOffice
	on
		OraTransSum.MerchantNo = MerWithBranchOffice.MerchantNo;

select
	MerWithBranchOffice.MerchantName,
	FactDailyTrans.MerchantNo,
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
	TransCount,
	convert(decimal, TransAmount)/100.0 TransAmount
into
	#AllTransSum
from
	(select
		MerchantName,
		MerchantNo,
		TransCount,
		TransAmount
	from
		#OraTransWithBO	
	union all
	select 
		MerchantName,
		MerchantNo,
		TransCount,
		TransAmount
	from
		#FactDailyTransWithBO	
	union all
	select
		MerchantName,
		MerchantNo,
		TransCount,
		TransAmount
	from
		#EmallTransSum) Mer; 
	
	
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

select
	MerchantName,
	MerchantNo,
	TransCount,
	TransAmount
from	
	#AllTransSum;


--9. drop temp table
drop table #OraTransSum;
drop table #FactDailyTrans;
drop table #EmallTransSum;
drop table #MerWithBranchOffice;
drop table #OraTransWithBO;
drop table #FactDailyTransWithBO;
drop table #AllTransSum;
drop table #SpecMerchantNo;

end

