if OBJECT_ID(N'Proc_QueryBranchOfficeSummarize',N'P') is not null
begin
	drop procedure Proc_QueryBranchOfficeSummarize;
end
go

create procedure Proc_QueryBranchOfficeSummarize
	@StartDate datetime = '2011-03-01',
	@PeriodUnit nChar(3) = N'月'
as 
begin


--1. Check Input
if (@StartDate is null or ISNULL(@PeriodUnit,N'') = N'')
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
	set @CurrEndDate = DATEADD(MONTH,3,@CurrStartDate);
end
else if(@PeriodUnit = N'半年')
begin
	set @CurrStartDate = LEFT(CONVERT(char,@StartDate,120),7) + '-01';
	set @CurrEndDate = DATEADD(MONTH,6,@CurrStartDate);
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
	MerchantNo,
	BranchOffice,
	SUM(ISNULL(SucceedTransCount,0)) TransCount,
	SUM(ISNULL(SucceedTransAmount,0)) TransAmount
into
	#EmallTransSum
from
	Table_EmallTransSum
where
	TransDate >= @CurrStartDate
	and
	TransDate < @CurrEndDate
	and
	BranchOffice in
(
	select
		DestBranchOffice
	from	
		Table_BranchOfficeNameMapping
)	
group by
	MerchantNo,
	BranchOffice;
	
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
select
	SalesDeptConfig.MerchantNo,
	BranchOfficeNameMapping.DestBranchOffice BranchOffice
into
	#MerWithBranch
from
	Table_SalesDeptConfiguration SalesDeptConfig
	inner join
	Table_BranchOfficeNameMapping BranchOfficeNameMapping
	on
		SalesDeptConfig.BranchOffice = BranchOfficeNameMapping.OrigBranchOffice;
		

--5. Get Respectively BranchOffice
select
	MerWithBranch.BranchOffice,
	MerWithBranch.MerchantNo,
	OraTransSum.TransCount,
	OraTransSum.TransAmount
into
	#MerWithBranchOra
from
	#MerWithBranch MerWithBranch
	left join
	#OraTransSum OraTransSum
	on
		MerWithBranch.MerchantNo = OraTransSum.MerchantNo;
	
select
	MerWithBranchOra.BranchOffice,
	MerWithBranchOra.MerchantNo,
	FactDailyTrans.TransCount,
	FactDailyTrans.TransAmount
into
	#MerWithBranchOraAndDaily
from
	#MerWithBranchOra MerWithBranchOra
	left join
	#FactDailyTrans FactDailyTrans
	on
		MerWithBranchOra.MerchantNo = FactDailyTrans.MerchantNo;


--6. Union All Data
select
	BranchOffice,
	MerchantNo,
	TransCount,
	TransAmount
into
	#AllMerWithBranch
from
	#MerWithBranchOraAndDaily
union all
select
	BranchOffice,
	MerchantNo,
	TransCount,
	TransAmount
from	
	#EmallTransSum;

	
--7. Get Result
select
	AllMerWithBranch.BranchOffice,
	COUNT(NewlyOpenMer.MerchantNo) NewlyIncreMerCount,
	CONVERT(decimal,SUM(ISNULL(AllMerWithBranch.TransCount,0))) / 10000 SumTransCount,
	CONVERT(decimal,SUM(ISNULL(AllMerWithBranch.TransAmount,0))) / 1000000 SumTransAmount 
into 
	#Result
from
	#AllMerWithBranch AllMerWithBranch
	left join
	#NewlyOpenMer NewlyOpenMer
	on
		AllMerWithBranch.MerchantNo = NewlyOpenMer.MerchantNo
group by
	AllMerWithBranch.BranchOffice;

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
	case when 
		S.WholeSum = 0
	then
		0
	else
	CONVERT(decimal,ISNULL(R.SumTransAmount,0)) / S.WholeSum 
	end Ratio
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
drop table #MerWithBranchOra;
drop table #MerWithBranchOraAndDaily;
drop table #AllMerWithBranch;
drop table #Result;

end