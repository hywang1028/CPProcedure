--[Modified] at 2012-07-13 by 王红燕  Description:Add Financial Dept Configuration Data
if OBJECT_ID(N'Proc_QueryUnionMerTransSum',N'P') is not null
begin
	drop procedure Proc_QueryUnionMerTransSum;
end
go

Create Procedure Proc_QueryUnionMerTransSum
	@StartDate datetime = '2011-06-12',
	@PeriodUnit nChar(3) = N'自定义',
	@EndDate datetime = '2011-09-12',
	@BranchOfficeName nChar(16) = N'中国银联股份有限公司安徽分公司'
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
end


--3.Get SpecifiedTimePeriod Data
select
	MerchantNo,
	(select MerchantName from Table_OraMerchants where MerchantNo = Table_OraTransSum.MerchantNo) MerchantName,
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
	(select MerchantName from Table_MerInfo where MerchantNo = FactDailyTrans.MerchantNo) MerchantName,
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
	BranchOfficeNameRule.UnionPaySpec = @BranchOfficeName
group by
	EmallTransSum.MerchantNo,
	EmallTransSum.MerchantName;
	

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
		BranchOfficeNameRule.UnnormalBranchOfficeName = SalesDeptConfiguration.BranchOffice
where 
	BranchOfficeNameRule.UnionPaySpec = @BranchOfficeName
union 
select
	Finance.MerchantNo
from
	Table_BranchOfficeNameRule BranchOfficeNameRule 
	inner join
	Table_FinancialDeptConfiguration Finance
	on
		BranchOfficeNameRule.UnnormalBranchOfficeName = Finance.BranchOffice
where 
	BranchOfficeNameRule.UnionPaySpec = @BranchOfficeName;
	
	
--5. Get TransDetail respectively
select
	OraTransSum.MerchantName,
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
	FactDailyTrans.MerchantName,
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

