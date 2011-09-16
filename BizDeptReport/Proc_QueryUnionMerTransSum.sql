if OBJECT_ID(N'Proc_QueryUnionMerTransSum',N'P') is not null
begin
	drop procedure Proc_QueryUnionMerTransSum;
end
go

Create Procedure Proc_QueryUnionMerTransSum
	@StartDate datetime = '2011-03-12',
	@PeriodUnit nChar(3) = N'月',
	@BranchOfficeName nChar(16) = N'中国银联股份有限公司内蒙古分公司'
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
	

--4. Get TransDetail respectively
select
	SalesDeptConfig.MerchantName,
	OraTransSum.MerchantNo,
	OraTransSum.TransCount,
	OraTransSum.TransAmount
into
	#OraTransWithBO
from
	#OraTransSum OraTransSum
	inner join
	Table_SalesDeptConfiguration SalesDeptConfig
	on
		OraTransSum.MerchantNo = SalesDeptConfig.MerchantNo
where
	SalesDeptConfig.BranchOffice = @BranchOfficeName;

	
select
	SalesDeptConfig.MerchantName,
	FactDailyTrans.MerchantNo,
	FactDailyTrans.SucceedTransCount as TransCount,
	FactDailyTrans.SucceedTransAmount as TransAmount
into
	#FactDailyTransWithBO
from
	#FactDailyTrans FactDailyTrans
	inner join
	Table_SalesDeptConfiguration SalesDeptConfig
	on
		FactDailyTrans.MerchantNo = SalesDeptConfig.MerchantNo
where
	SalesDeptConfig.BranchOffice = @BranchOfficeName;

	
--5. Union all Trans
select
	MerchantName,
	MerchantNo,
	TransCount,
	convert(decimal, TransAmount)/100.0 TransAmount
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
	

--6. drop temp table
drop table #OraTransSum;
drop table #FactDailyTrans;
drop table #EmallTransSum;
drop table #OraTransWithBO;
drop table #FactDailyTransWithBO;

end

