--Created by chen.wu on 2013.11.20

if OBJECT_ID(N'Proc_NewMerTransByMonth',N'P') is not null
begin
	drop procedure Proc_NewMerTransByMonth
end
go

create procedure Proc_NewMerTransByMonth
	@OpenAccountStartDate date,
	@OpenAccountEndDate date,
	@MerchantType nvarchar(10) = N'',
	@StartDate date,
	@EndDate date
as
begin

--declare	@OpenAccountStartDate date;
--declare	@OpenAccountEndDate date;
--declare	@MerchantType nvarchar(10);
--declare	@StartDate date;
--declare	@EndDate date;

--set @OpenAccountStartDate = '2013-01-01';
--set @OpenAccountEndDate = '2013-02-01';
--set @MerchantType = N'';
--set @StartDate = '2013-03-01';
--set @EndDate = '2013-07-01';

	
--1. Check input params
if (@OpenAccountStartDate is null
	or @OpenAccountEndDate is null
	or @StartDate is null
	or @EndDate is null)
begin
	raiserror(N'Input date parameters cannot be empty.', 16, 1);  
end

if (@OpenAccountEndDate < @OpenAccountStartDate
	or @EndDate < @StartDate)
begin
	raiserror(N'End date cannot earlier than start date.', 16, 1);  	
end

--2. Adjust end date
set @OpenAccountEndDate = DATEADD(day, 1, @OpenAccountEndDate);
set @EndDate = DATEADD(day, 1, @EndDate);

--3. Get open account merchants
select
	MerchantNo,
	MerchantName,
	MerchantType
into
	#OpenAccountMers
from
	Table_MerOpenAccountInfo
where
	OpenAccountDate >= @OpenAccountStartDate
	and
	OpenAccountDate < @OpenAccountEndDate
	and
	MerchantType = (case when 
						@MerchantType = N'' 
					then 
						MerchantType 
					else 
						@MerchantType 
					end);

--4. FactDailyTrans
select
	MerchantNo,
	convert(nvarchar(7),DailyTransDate,120) as YearMonth,
	SUM(DailyTransCount) as TransCnt,
	SUM(SucceedTransCount) as SucceedTransCnt,
	SUM(SucceedTransAmount) as SucceedTransAmt
into
	#FactDailyTrans
from
	FactDailyTrans
where
	DailyTransDate >= @StartDate
	and
	DailyTransDate < @EndDate
	and
	MerchantNo in (select MerchantNo from #OpenAccountMers)
group by
	MerchantNo,
	convert(nvarchar(7),DailyTransDate,120);
	
--4.1 update foreign merchant currency
with CuryFullRate as
(
	select
		CuryCode,
		AVG(CuryRate) as CuryRate
	from
		Table_CuryFullRate
	where
		CuryDate >= @StartDate
		and
		CuryDate < @EndDate
	group by
		CuryCode
)
update
	trans
set
	trans.SucceedTransAmt = trans.SucceedTransAmt * rate.CuryRate
from
	#FactDailyTrans trans
	inner join
	Table_MerInfoExt ext
	on
		trans.MerchantNo = ext.MerchantNo
	inner join
	CuryFullRate rate
	on
		ext.CuryCode = rate.CuryCode;

--5. TraScreenSum
select
	MerchantNo,
	convert(nvarchar(7),CPDate,120) as YearMonth,
	SUM(TotalCnt) as TransCnt,
	SUM(SucceedCnt) as SucceedTransCnt,
	SUM(SucceedAmt) as SucceedTransAmt
into
	#TraScreenSum
from
	Table_TraScreenSum
where
	CPDate >= @StartDate
	and
	CPDate < @EndDate
	and
	MerchantNo in (select MerchantNo from #OpenAccountMers)
group by
	MerchantNo,
	convert(nvarchar(7),CPDate,120);

--6. OraTransSum
select
	MerchantNo,
	convert(nvarchar(7),CPDate,120) as YearMonth,
	SUM(TransCount) as TransCnt,
	SUM(TransCount) as SucceedTransCnt,
	SUM(TransAmount) as SucceedTransAmt
into
	#OraTransSum
from
	Table_OraTransSum
where
	CPDate >= @StartDate
	and
	CPDate < @EndDate
	and
	MerchantNo in (select MerchantNo from #OpenAccountMers)	
group by
	MerchantNo,
	convert(nvarchar(7),CPDate,120);
	
--7. UpopliqFeeLiqResult
select
	relation.CpMerNo as MerchantNo,
	convert(nvarchar(7),upop.TransDate,120) as YearMonth,
	SUM(upop.PurCnt) as TransCnt,
	SUM(upop.PurCnt) as SucceedTransCnt,
	SUM(upop.PurAmt) as SucceedTransAmt
into
	#UpopliqFeeLiqResult
from
	Table_UpopliqFeeLiqResult upop
	inner join
	Table_CpUpopRelation relation
	on
		upop.MerchantNo = relation.UpopMerNo
where
	upop.TransDate >= @StartDate
	and
	upop.TransDate < @EndDate
	and
	relation.CpMerNo in (select MerchantNo from #OpenAccountMers)
group by
	relation.CpMerNo,
	convert(nvarchar(7),upop.TransDate,120);

--8. All Data
With AllData as
(
select
	MerchantNo,
	YearMonth,
	TransCnt,
	SucceedTransCnt,
	SucceedTransAmt
from
	#FactDailyTrans
union all
select
	MerchantNo,
	YearMonth,
	TransCnt,
	SucceedTransCnt,
	SucceedTransAmt
from
	#TraScreenSum
union all
select
	MerchantNo,
	YearMonth,
	TransCnt,
	SucceedTransCnt,
	SucceedTransAmt
from
	#OraTransSum
union all
select
	MerchantNo,
	YearMonth,
	TransCnt,
	SucceedTransCnt,
	SucceedTransAmt
from
	#UpopliqFeeLiqResult
)
select
	MerchantNo,
	YearMonth,
	SUM(TransCnt) as TransCnt,
	SUM(SucceedTransCnt) as SucceedTransCnt,
	SUM(SucceedTransAmt)/100.0 as SucceedTransAmt
into
	#AllData
from
	AllData
group by
	MerchantNo,
	YearMonth;

create table #Period
(
	YearMonth nvarchar(40)
);
declare @FirstDate date;
set @FirstDate = DATEADD(day, -(DAY(@StartDate)-1), @StartDate);
while (@EndDate > @FirstDate)
begin
	insert into #Period
	(
		YearMonth
	)
	values
	(
		convert(nvarchar(7),@FirstDate,120)
	);
	
	set @FirstDate = DATEADD(month, 1, @FirstDate);
end
	
select
	mers.MerchantType,
	mers.MerchantNo,
	mers.MerchantName,
	p.YearMonth,
	isnull(ad.TransCnt, 0) as TransCnt,
	isnull(ad.SucceedTransCnt, 0) as SucceedTransCnt,
	isnull(ad.SucceedTransAmt, 0) as SucceedTransAmt
from
	#OpenAccountMers mers
	cross join
	#Period p
	left join
	#AllData ad
	on
		mers.MerchantNo = ad.MerchantNo
		and
		p.YearMonth = ad.YearMonth;
		
		
	
--9. Pivot result
--select distinct
--	YearMonth
--into
--	#Period
--from
--	#AllData
--order by
--	YearMonth;

--declare @sql nvarchar(max);
--set @sql = N'select
--				MerchantNo';
--select
--	@sql = @sql 
--			+ ',max(case YearMonth when ''' +p.YearMonth+ ''' then TransCnt else 0 end) [' + p.YearMonth + N'消费总笔数]'
--			+ ',max(case YearMonth when ''' +p.YearMonth+ ''' then SucceedTransCnt else 0 end) [' + p.YearMonth + N'消费成功笔数]'
--			+ ',max(case YearMonth when ''' +p.YearMonth+ ''' then SucceedTransAmt else 0 end) [' + p.YearMonth + N'消费成功金额]'
--from
--	#Period p;
	
--set @sql = @sql
--			+ ' into #PivotData'
--			+ ' from #AllData group by MerchantNo;';

----10. Final result
--declare @colSql nvarchar(max) = N'';
--select
--	@colSql = @colSql + ',isnull([' + p.YearMonth + N'消费总笔数],0) as ' + '[' + p.YearMonth + N'消费总笔数]'
--				+ ',isnull([' + p.YearMonth + N'消费成功笔数],0) as ' +  '[' + p.YearMonth + N'消费成功笔数]'
--				+ ',isnull([' + p.YearMonth + N'消费成功金额],0) as ' +  '[' + p.YearMonth + N'消费成功金额]'
--from
--	#Period p;

--set @sql = @sql + 
--N'select
--	mers.MerchantType,
--	mers.MerchantNo,
--	mers.MerchantName'
--	+ @colSql
--+N'
--from
--	#OpenAccountMers mers
--	left join
--	#PivotData pd
--	on
--		mers.MerchantNo = pd.MerchantNo;'
		
--exec(@sql);

--11. Clear temp tables
drop table #OpenAccountMers;
drop table #FactDailyTrans;
drop table #TraScreenSum;
drop table #OraTransSum;
drop table #UpopliqFeeLiqResult;
--drop table #Period;
drop table #AllData;

end

