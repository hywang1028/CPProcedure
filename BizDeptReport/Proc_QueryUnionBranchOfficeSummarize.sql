if OBJECT_ID(N'Proc_QueryUnionBranchOfficeSummarize',N'P') is not null
begin
	drop procedure Proc_QueryUnionBranchOfficeSummarize;
end
go

create procedure Proc_QueryUnionBranchOfficeSummarize
	@StartDate datetime = '2011-03-21',
	@EndDate datetime = '2011-07-12',
	@PeriodUnit nChar(3) = N'��'
as 
begin


--1. Check Input
if (@StartDate is null or ISNULL(@PeriodUnit,N'') = N'' or (@PeriodUnit = N'�Զ���' and @EndDate is null))
begin
	raiserror('Input parameters can`t be empty in Proc_QueryUnionBranchOfficeSummarize!',16,1);
end


--2. Prepare StartDate and EndDate
declare @CurrStartDate datetime;
declare @CurrEndDate datetime;

if (@PeriodUnit = N'��')
begin
	set @CurrStartDate = LEFT(CONVERT(char,@StartDate,120),7) + '-01';
	set @CurrEndDate = DATEADD(month,1,@CurrStartDate);
end
else if(@PeriodUnit = N'����')
begin
	set @CurrStartDate = LEFT(CONVERT(char,@StartDate,120),7) + '-01';
	set @CurrEndDate = DATEADD(QUARTER,1,@CurrStartDate);
end
else if(@PeriodUnit = N'����')
begin
	set @CurrStartDate = LEFT(CONVERT(char,@StartDate,120),7) + '-01';
	set @CurrEndDate = DATEADD(QUARTER,2,@CurrStartDate);
end
else if(@PeriodUnit = N'�Զ���')
begin
	set @CurrStartDate = LEFT(CONVERT(char,@StartDate,120),7) + '-01';
	set @CurrEndDate = LEFT(CONVERT(char,DATEADD(MONTH,1,@EndDate),120),7) + '-01';
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
	select distinct
		BranchOffice
	from
		Table_SalesDeptConfiguration 
	where
		Channel = N'����'
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
	BranchOffice, 
	MerchantNo
into
	#MerWithBranch
from
	Table_SalesDeptConfiguration 
where
	Channel = N'����'
		
		
--5. Get Respectively BranchOffice
select
	MerWithBranch.BranchOffice,
	OraTransSum.MerchantNo,
	OraTransSum.TransCount,
	OraTransSum.TransAmount
into
	#OraAndDaily
from
	#MerWithBranch MerWithBranch
	inner join
	#OraTransSum OraTransSum
	on
		MerWithBranch.MerchantNo = OraTransSum.MerchantNo
union all	
select
	MerWithBranch.BranchOffice,
	FactDailyTrans.MerchantNo,
	FactDailyTrans.TransCount,
	FactDailyTrans.TransAmount
from
	#MerWithBranch MerWithBranch
	inner join
	#FactDailyTrans FactDailyTrans
	on
		MerWithBranch.MerchantNo = FactDailyTrans.MerchantNo;

select
	MerWithBranch.BranchOffice,
	MerWithBranch.MerchantNo,
	OraAndDaily.TransCount,
	OraAndDaily.TransAmount
into
	#OraAndDailyWithBranch
from
	#MerWithBranch MerWithBranch
	left join
	#OraAndDaily OraAndDaily
	on
		MerWithBranch.MerchantNo = OraAndDaily.MerchantNo;


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
	end Ratio,
	case when 
		R.BranchOffice = N'�й������ɷ����޹�˾�������ֹ�˾'
	then
		N'������'
	when
		R.BranchOffice = N'�й������ɷ����޹�˾���ɹŷֹ�˾'
	then
		N'���ɹ�'
	else
		SUBSTRING(R.BranchOffice,11,2)
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
drop table #OraAndDaily;
drop table #OraAndDailyWithBranch;
drop table #AllMerWithBranch;
drop table #Result;

end