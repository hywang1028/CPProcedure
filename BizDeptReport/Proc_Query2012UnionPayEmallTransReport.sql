if OBJECT_ID(N'Proc_Query2012UnionPayEmallTransReport', N'P') is not null
begin
	drop procedure Proc_Query2012UnionPayEmallTransReport;
end
go

create procedure Proc_Query2012UnionPayEmallTransReport
	@StartDate datetime = '2012-01-01',
	@PeriodUnit nchar(4) = N'月',
	@EndDate datetime = '2012-02-01'
as
begin

--1. Check input
if (@StartDate is null or ISNULL(@PeriodUnit, N'') = N''  or (@PeriodUnit = N'自定义' and @EndDate is null))
begin
	raiserror(N'Input params cannot be empty in Proc_Query2012UnionPayEmallTransReport', 16, 1);
end

--2. Prepare StartDate and EndDate
declare @CurrStartDate datetime;
declare @CurrEndDate datetime;

if(@PeriodUnit = N'月')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(MONTH, 1, @StartDate);
end
else if(@PeriodUnit = N'季度')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(QUARTER, 1, @StartDate);
end
else if(@PeriodUnit = N'半年')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(QUARTER, 2, @StartDate);
end
else if(@PeriodUnit = N'年')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(YEAR, 1, @StartDate);
end
else if(@PeriodUnit = N'自定义')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DateAdd(day,1,@EndDate);
end;

--3. Prepare Emall Trans Data
With Emall as
(
	select 
		MerchantNo,
		MerchantName,
		BranchOffice,
		Province,
		City,
		SUM(SucceedTransCount) SucceedTransCount,
		Convert(decimal,SUM(SucceedTransAmount))/100 SucceedTransAmount
	 from
		Table_EmallTransSum
	 where
		TransDate >= @CurrStartDate
		and
		TransDate <  @CurrEndDate
	group by
		MerchantNo,
		MerchantName,
		BranchOffice,
		Province,
		City
)
select 
	Emall.MerchantNo,
	Emall.MerchantName,
	Emall.BranchOffice,
	ISNULL(BranchOffice.UnionPaySpec,N'') as DestBranchOffice,
	Emall.SucceedTransCount,
	Emall.SucceedTransAmount,
	Emall.Province,
	Emall.City
into
	#EmallTransData
from 
	Emall
	left join
	Table_BranchOfficeNameRule BranchOffice
	on
		Emall.BranchOffice = BranchOffice.UnnormalBranchOfficeName;
	
--4. Update BranchOffice Info
update 
	Emall
set
	Emall.DestBranchOffice = ISNULL(BranchOffice.UnionPaySpec,N'')
from 
	#EmallTransData Emall
	inner join
	Table_BranchOfficeNameRule BranchOffice
	on
		Emall.City = BranchOffice.BranchOfficeShortName
where
	Emall.DestBranchOffice = N''
	and
	Emall.City is not null;
					
update 
	Emall
set
	Emall.DestBranchOffice = ISNULL(BranchOffice.UnionPaySpec,N'')
from
	#EmallTransData Emall
	inner join 
	Table_BranchOfficeNameRule BranchOffice
	on
		Emall.Province = BranchOffice.BranchOfficeShortName
where
	Emall.DestBranchOffice = N''
	and
	Emall.Province is not null;
	
update 
	#EmallTransData
set
	DestBranchOffice = ISNULL(BranchOffice,N'')
where
	DestBranchOffice = N''
	and
	BranchOffice like '%馆';

--5. Get Result
select 
	Trans.DestBranchOffice,
	Trans.MerchantNo,
	Trans.MerchantName,
	N'网络购物' as IndustryName,
	ISNULL(Convert(char(10),Mer.OpenTime,120),N'') OpenTime,
	Trans.SucceedTransCount,
	Trans.SucceedTransAmount
from 
	#EmallTransData Trans
	left join
	Table_EmallMerInfo Mer
	on
		Trans.MerchantNo = Mer.MerchantNo
order by 
	Trans.DestBranchOffice;
		
--6. Drop Table 
Drop Table #EmallTransData;

End