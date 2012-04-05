--[Created] At 20120331 By 叶博：B2C行业排名报表
--Input:@StartDate,@EndDate;
--Output:BankName,IndustryName,CurrTransCnt,CurrTransAmt,PrevTransAmt,BankTransCnt,BankTransAmt,TotalCnt,TotalAmt,IndustryRank
if OBJECT_ID(N'Proc_QueryIndustryRankInCategoryB2C',N'P') is not null
begin
	drop procedure Proc_QueryIndustryRankInCategoryB2C;
end
go

create procedure Proc_QueryIndustryRankInCategoryB2C
	@StartDate datetime = '2012-02-01',
	@EndDate datetime = '2012-02-29'
as
begin


--1.Check Input
if(@StartDate is null or @EndDate is null)
begin
	raiserror('Input Parameters can`t be empty in Proc_QueryIndustryRankInCategoryB2C',16,1);
end


--2. Prepare @StartDate&@EndDate
declare @CurrStartDate datetime;  
declare @CurrEndDate datetime;  
declare @PrevStartDate datetime;  
declare @PrevEndDate datetime;  
begin  
set @CurrStartDate = @StartDate;  
set @CurrEndDate = DATEADD(DAY,1,@EndDate);  
  
if(DAY(@CurrStartDate)=1 and DAY(@CurrEndDate)=1)  
begin  
 set @PrevStartDate = DATEADD(MONTH,(-1) * DATEDIFF(MONTH,@CurrStartDate,@CurrEndDate),@CurrStartDate);
 set @PrevEndDate = DATEADD(MONTH,(-1) * DATEDIFF(MONTH,@CurrStartDate,@CurrEndDate),@CurrEndDate);
end  
else  
begin  
 set @PrevStartDate = DATEADD(DAY, (-1)* DATEDIFF(DAY,@CurrStartDate,@CurrEndDate), @CurrStartDate);  
 set @PrevEndDate = @CurrStartDate;  
end  
 
end  

declare @BizType nvarchar(20);
begin
set @BizType = N'B2C';
end


--3.Get Trans Data Whose BizType is B2C By Current,Previous
select
	BankChannel.BankName,
	Fact.MerchantNo,
	SUM(Fact.SucceedTransCount) TransCnt,
	SUM(Fact.SucceedTransAmount) TransAmt
into
	#Curr
from
	FactDailyTrans Fact
	inner join
	Table_FinancialDeptBankChannelMapping BankChannel
	on
		Fact.GateNo = BankChannel.BankChannel
	where
		Fact.DailyTransDate >= @CurrStartDate
		and
		Fact.DailyTransDate < @CurrEndDate
		and
		BankChannel.BizType = @BizType
group by
		Fact.MerchantNo,
		BankChannel.BankName;
		
select
	BankChannel.BankName,
	Fact.MerchantNo,
	SUM(Fact.SucceedTransCount) TransCnt,
	SUM(Fact.SucceedTransAmount) TransAmt
into
	#Prev
from
	FactDailyTrans Fact
	inner join
	Table_FinancialDeptBankChannelMapping BankChannel
	on
		Fact.GateNo = BankChannel.BankChannel
	where
		Fact.DailyTransDate >= @PrevStartDate
		and
		Fact.DailyTransDate < @PrevEndDate
		and
		BankChannel.BizType = @BizType
	group by
		Fact.MerchantNo,
		BankChannel.BankName;

declare @TotalCnt bigint;
declare @TotalAmt bigint;
select 
	@TotalCnt = SUM(TransCnt), 
	@TotalAmt = SUM(TransAmt)
from
	#Curr;


--4.Get Result
--4.1 Join Different Period Trans Data
select
	coalesce(Curr.BankName,Prev.BankName) as BankName,
	ISNULL(Sales.IndustryName,N'未配置行业') as IndustryName,
	SUM(ISNULL(Curr.TransCnt,0)) as CurrTransCnt,
	SUM(ISNULL(Curr.TransAmt,0)) as CurrTransAmt,
	SUM(ISNULL(Prev.TransAmt,0)) as PrevTransAmt
into	
	#Result
from
	#Curr Curr
	full outer join
	#Prev Prev
	on
		Curr.BankName = Prev.BankName
		and
		Curr.MerchantNo = Prev.MerchantNo
	left join
	Table_SalesDeptConfiguration Sales
	on
		coalesce(Curr.MerchantNo,Prev.MerchantNo) = Sales.MerchantNo
group by
	coalesce(Curr.BankName,Prev.BankName),
	Sales.IndustryName;

--4.2 Get B2C Trans Data By Bank
With #CurrByBank as
(
	select
		BankName,
		SUM(TransCnt) TransCnt,
		SUM(TransAmt) TransAmt
	from
		#Curr
	group by
		BankName
)
select
	R.BankName,
	R.IndustryName,
	R.CurrTransCnt,
	R.CurrTransAmt,
	R.PrevTransAmt,
	ISNULl(CurrByBank.TransCnt,0) as BankTransCnt,
	ISNULL(CurrByBank.TransAmt,0) as BankTransAmt,
	@TotalCnt as TotalCnt,
	@TotalAmt as TotalAmt,
	NTILE(30) OVER(PARTITION BY R.BankName ORDER BY R.PrevTransAmt desc) as IndustryRank
from
	#Result R
	left join
	#CurrByBank CurrByBank
	on
		R.BankName = CurrByBank.BankName
order by
	R.BankName,
	R.CurrTransAmt desc,
	R.IndustryName;
	

--5.Drop Temporary Tables
drop table #Curr;
drop table #Prev;


end