--[Created] At 20120331 By 丁俊昊：B2C商户排名报表
--Input:@StartDate,@EndDate;
--Output:BankName,MerchantName,CurrTransCnt,CurrTransAmt,PrevTransAmt,BankTransCnt,BankTransAmt,TotalCnt,TotalAmt,MerchantRank
if OBJECT_ID(N'Proc_QueryMerchantRankInCategoryB2C',N'P') is not null
begin
	drop Procedure Proc_QueryMerchantRankInCategoryB2C
end
go

create procedure Proc_QueryMerchantRankInCategoryB2C
	@StartDate datetime = '2012-02-01',
	@EndDate datetime = '2012-02-29'
as
begin


--1. Check Input
if(@StartDate is null or @EndDate is null )
begin
	raiserror('Input Parameters can`t be empty in Proc_QueryMerchantRankInCategoryB2C',16,1);
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
end  
else  
begin  
 set @PrevStartDate = DATEADD(DAY, (-1)* DATEDIFF(DAY,@CurrStartDate,@CurrEndDate), @CurrStartDate);  
end  
set @PrevEndDate = @CurrStartDate;  
end 


--3.1 本周期交易金额和笔数
select
	FinancialDept.BankName,
	FactDaily.MerchantNo,
	SUM(FactDaily.SucceedTransAmount) as TransAmt,
	SUM(FactDaily.SucceedTransCount) as TransCnt
into
	#CurrData
from
	Table_FinancialDeptBankChannelMapping FinancialDept
	inner join
	FactDailyTrans FactDaily
	on
		FinancialDept.BankChannel = FactDaily.GateNo
where
	FinancialDept.BizType = N'B2C'
	and
	DailyTransDate >= @CurrStartDate
	and
	DailyTransDate < @CurrEndDate
group by
	FinancialDept.BankName,
	FactDaily.MerchantNo


--3.2 上周期交易金额和笔数
select
	FinancialDept.BankName,
	FactDaily.MerchantNo,
	SUM(FactDaily.SucceedTransAmount) as TransAmt,
	SUM(FactDaily.SucceedTransCount) as TransCnt
into
	#PrevData
from
	Table_FinancialDeptBankChannelMapping FinancialDept
	inner join
	FactDailyTrans FactDaily
	on
		FinancialDept.BankChannel = FactDaily.GateNo
where
	FinancialDept.BizType = N'B2C'
	and
	DailyTransDate >= @PrevStartDate
	and
	DailyTransDate < @PrevEndDate
group by
	FinancialDept.BankName,
	FactDaily.MerchantNo


--4.得到本期银行力度下的交易总额和交易笔数总额
select
	Curr.BankName,
	sum(Curr.TransAmt) BankAmt,
	sum(Curr.TransCnt) BankCnt
into
	#BankAmtCnt
from
	#CurrData Curr
group by
	Curr.BankName
	
declare @TotalAmt bigint;
declare @TotalCnt bigint;
select
	@TotalAmt = SUM(Bank.BankAmt),
	@TotalCnt = SUM(Bank.BankCnt)
from	
	#BankAmtCnt Bank

select
	coalesce(Curr.BankName,Prev.BankName) BankName,
	ISNULL(SalesDept.MerchantName,N'未配置商户') as MerchantName,
	ISNULL(Curr.TransCnt,0) as CurrTransCnt,
	ISNULL(Curr.TransAmt,0) as CurrTransAmt,
	ISNULL(Prev.TransAmt,0) as PrevTransAmt,
	ISNULL(Bank.BankCnt,0) as BankTransCnt,
	ISNULL(Bank.BankAmt,0) as BankTransAmt,
	@TotalCnt as TotalCnt,
	@TotalAmt as TotalAmt,
	NTILE(2000) OVER(PARTITION BY coalesce(Curr.BankName,Prev.BankName) ORDER BY Prev.TransAmt desc) as MerchantRank
from
	#CurrData Curr
	full outer join
	#PrevData Prev
	on
		Curr.MerchantNo = Prev.MerchantNo
		and
		Curr.BankName = Prev.BankName
	left join
	Table_SalesDeptConfiguration SalesDept
	on
		coalesce(Curr.MerchantNo,Prev.MerchantNo) = SalesDept.MerchantNo
	left join
	#BankAmtCnt Bank
	on
		coalesce(Curr.BankName,Prev.BankName) = Bank.BankName 
order by
	BankName,
	CurrTransAmt desc;
	

--5. Drop Temporary Tables
drop table #CurrData;
drop table #PrevData;
drop table #BankAmtCnt;

end