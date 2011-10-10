if OBJECT_ID(N'Proc_QueryMerTransSumWithBranchOffice',N'P') is not null
begin
	drop procedure Proc_QueryMerTransSumWithBranchOffice;
end
go

Create Procedure Proc_QueryMerTransSumWithBranchOffice
	@StartDate datetime = '2010-01-12',
	@PeriodUnit nChar(3) = N'自定义',
	@EndDate datetime = '2011-09-06',
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
	set @CurrStartDate = left(CONVERT(char,@StartDate,120),7) + '-01';
	set @CurrEndDate =   DATEADD(MONTH,1,left(CONVERT(char,@EndDate,120),7) + '-01');
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
	MerchantNo,
	MerchantName,
	sum(SucceedTransCount) TransCount,
	sum(SucceedTransAmount) TransAmount
into 
	#EmallTransSum
from	
	Table_EmallTransSum
where 
	TransDate >= @CurrStartDate
	and
	TransDate < @CurrEndDate
	and
	BranchOffice = @BranchOfficeName
group by
	MerchantNo,
	MerchantName;

--4. Get table MerWithBranchOffice
select
	SalesDeptConfiguration.MerchantName,
	SalesDeptConfiguration.MerchantNo
into
	#MerWithBranchOffice
from
	Table_BranchOfficeNameMapping BranchOfficeNameMapping 
	inner join
	Table_SalesDeptConfiguration SalesDeptConfiguration
	on
		BranchOfficeNameMapping.OrigBranchOffice = SalesDeptConfiguration.BranchOffice
where 
	BranchOfficeNameMapping.DestBranchOffice = @BranchOfficeName;

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
	MerchantNo
into
	#SpecMerchantNo
from
	Table_SalesDeptConfiguration
where
	BranchOffice in (N'中国银联股份有限公司重庆分公司',N'中国银联股份有限公司湖南分公司',N'中国银联股份有限公司宁波分公司',N'中国银联股份有限公司四川分公司');
	

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

