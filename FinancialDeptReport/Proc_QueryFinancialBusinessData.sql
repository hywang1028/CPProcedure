--[Modified] At 20120331 By 叶博：修改环比计算参数的逻辑
--Input:@StartDate,@EndDate,@BizType
--Output:BankName,BankChannel,DailyTransCount,CurrTransCount,CurrTransAmount,PrevTransCount,PrevTransAmount,LastYearTransCount,LastYearTransAmount,SumAmt
if OBJECT_ID(N'Proc_QueryFinancialBusinessData',N'P') is not null
begin
	drop Procedure Proc_QueryFinancialBusinessData
end
go

create procedure Proc_QueryFinancialBusinessData
	@StartDate datetime = '2012-03-01',
	@EndDate datetime = '2012-03-20',
	@BizType nvarchar(20) = N'B2C'
as
begin


--1. Check Input
if(@StartDate is null or @EndDate is null or ISNULL(@BizType,N'') =N'')
begin
	raiserror('Input Parameters can`t be empty in Proc_QueryFinancialBusinessData',16,1);
end


--2. Prepare @StartDate&@EndDate
declare @CurrStartDate datetime;  
declare @CurrEndDate datetime;  
declare @PrevStartDate datetime;  
declare @PrevEndDate datetime;  
declare @LastYearStartDate datetime;  
declare @LastYearEndDate datetime;  
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
set @LastYearStartDate = DATEADD(YEAR,-1,@CurrStartDate);  
set @LastYearEndDate = DATEADD(YEAR,-1,@CurrEndDate);  
end  

--3.Get Data By BizType&Date
create table #CurrDaily
(
	BankName nchar(20),
	BankChannel nchar(20),
	DailyTransCount bigint,
	TransCount bigint,
	TransAmount bigint
);

create table #PrevDaily
(
	BankName nchar(20),
	BankChannel nchar(20),
	DailyTransCount bigint,
	TransCount bigint,
	TransAmount bigint
);

create table #LastYearDaily
(
	BankName nchar(20),
	BankChannel nchar(20),
	DailyTransCount bigint,
	TransCount bigint,
	TransAmount bigint
);
	
--3.1 Get each Period FactDailyTrans Data
if(@BizType <> N'ORA')
begin
	insert into	#CurrDaily
	(
		BankName,
		BankChannel,
		DailyTransCount,
		TransCount,
		TransAmount
	)
	select
		BankChannelMap.BankName,
		BankChannelMap.BankChannel,
		sum(DaiyTrans.DailyTransCount) DailyTransCount,
		sum(DaiyTrans.SucceedTransCount) TransCount,
		sum(DaiyTrans.SucceedTransAmount) TransAmount
	from
		FactDailyTrans DaiyTrans
		inner join
		Table_FinancialDeptBankChannelMapping BankChannelMap
		on
			DaiyTrans.GateNo = BankChannelMap.BankChannel
	where
		DailyTransDate >= @CurrStartDate
		and
		DailyTransDate < @CurrEndDate
		and
		BankChannelMap.BizType = @BizType
	group by
		BankChannelMap.BankChannel,
		BankChannelMap.BankName;
		
	insert 	into #PrevDaily
	(
		BankName,
		BankChannel,
		DailyTransCount,
		TransCount,
		TransAmount
	)
	select
		BankChannelMap.BankName,
		BankChannelMap.BankChannel,
		sum(DaiyTrans.DailyTransCount) DailyTransCount,
		sum(DaiyTrans.SucceedTransCount) TransCount,
		sum(DaiyTrans.SucceedTransAmount) TransAmount
	from
		FactDailyTrans DaiyTrans
		inner join
		Table_FinancialDeptBankChannelMapping BankChannelMap
		on
			DaiyTrans.GateNo = BankChannelMap.BankChannel
	where
		DailyTransDate >= @PrevStartDate
		and
		DailyTransDate < @PrevEndDate
		and
		BankChannelMap.BizType = @BizType
	group by
		BankChannelMap.BankChannel,
		BankChannelMap.BankName;
		
	insert 	into #LastYearDaily
	(
		BankName,
		BankChannel,
		DailyTransCount,
		TransCount,
		TransAmount
	)
	select
		BankChannelMap.BankName,
		BankChannelMap.BankChannel,
		sum(DaiyTrans.DailyTransCount) DailyTransCount,
		sum(DaiyTrans.SucceedTransCount) TransCount,
		sum(DaiyTrans.SucceedTransAmount) TransAmount
	from
		FactDailyTrans DaiyTrans
		inner join
		Table_FinancialDeptBankChannelMapping BankChannelMap
		on
			DaiyTrans.GateNo = BankChannelMap.BankChannel
	where
		DailyTransDate >= @LastYearStartDate
		and
		DailyTransDate < @LastYearEndDate
		and
		BankChannelMap.BizType = @BizType
	group by
		BankChannelMap.BankChannel,
		BankChannelMap.BankName;
end

--3.2 Get Each Period OraTrans Data
else if(@BizType = N'ORA')
begin
	insert 	into #CurrDaily
	(
		BankName,
		BankChannel,
		DailyTransCount,
		TransCount,
		TransAmount
	)
	select
		BankChannelMap.BankName,
		BankChannelMap.BankChannel,
		0 as DailyTransCount,
		sum(OraTrans.TransCount) TransCount,
		sum(OraTrans.TransAmount) TransAmount
	from
		Table_OraTransSum OraTrans
		inner join
		Table_OraBankSetting OraBankSetting
		on
			OraTrans.BankSettingID = OraBankSetting.BankSettingID
		inner join
		Table_FinancialDeptBankChannelMapping BankChannelMap
		on
			OraBankSetting.BankName = BankChannelMap.BankChannel
	where
		OraTrans.CPDate >= @CurrStartDate
		and
		OraTrans.CPDate < @CurrEndDate
		and
		BankChannelMap.BizType = @BizType
	group by
		BankChannelMap.BankChannel,
		BankChannelMap.BankName;
		
	insert 	into #PrevDaily
	(
		BankName,
		BankChannel,
		DailyTransCount,
		TransCount,
		TransAmount
	)
	select
		BankChannelMap.BankName,
		BankChannelMap.BankChannel,
		0 as DailyTransCount,
		sum(OraTrans.TransCount) TransCount,
		sum(OraTrans.TransAmount) TransAmount
	from
		Table_OraTransSum OraTrans
		inner join
		Table_OraBankSetting OraBankSetting
		on
			OraTrans.BankSettingID = OraBankSetting.BankSettingID
		inner join
		Table_FinancialDeptBankChannelMapping BankChannelMap
		on
			OraBankSetting.BankName = BankChannelMap.BankChannel
	where
		OraTrans.CPDate >= @PrevStartDate
		and
		OraTrans.CPDate < @PrevEndDate
		and
		BankChannelMap.BizType = @BizType
	group by
		BankChannelMap.BankChannel,
		BankChannelMap.BankName;
		
	insert 	into #LastYearDaily
	(
		BankName,
		BankChannel,
		DailyTransCount,
		TransCount,
		TransAmount
	)
	select
		BankChannelMap.BankName,
		BankChannelMap.BankChannel,
		0 as DailyTransCount,
		sum(OraTrans.TransCount) TransCount,
		sum(OraTrans.TransAmount) TransAmount
	from
		Table_OraTransSum OraTrans
		inner join
		Table_OraBankSetting OraBankSetting
		on
			OraTrans.BankSettingID = OraBankSetting.BankSettingID
		inner join
		Table_FinancialDeptBankChannelMapping BankChannelMap
		on
			OraBankSetting.BankName = BankChannelMap.BankChannel
	where
		OraTrans.CPDate >= @LastYearStartDate
		and
		OraTrans.CPDate < @LastYearEndDate
		and
		BankChannelMap.BizType = @BizType
	group by
		BankChannelMap.BankChannel,
		BankChannelMap.BankName;
end	
	
--4. Get ResultSet
declare @Sum bigint;
select
	@Sum = SUM(ISNULL(TransAmount,0))
from	
	#CurrDaily;	
	
select
	coalesce(CurrDaily.BankName,PrevDaily.BankName,LastYearDaily.BankName) BankName,
	coalesce(CurrDaily.BankChannel,PrevDaily.BankChannel,LastYearDaily.BankChannel) BankChannel,
	ISNULL(CurrDaily.DailyTransCount,0) DailyTransCount,
	ISNULL(CurrDaily.TransCount,0) CurrTransCount,
	ISNULL(CurrDaily.TransAmount,0) CurrTransAmount,
	ISNULL(PrevDaily.TransCount,0) PrevTransCount,
	ISNULL(PrevDaily.TransAmount,0) PrevTransAmount,
	ISNULL(LastYearDaily.TransCount,0) LastYearTransCount,
	ISNULL(LastYearDaily.TransAmount,0) LastYearTransAmount,
	@Sum SumAmt
from
	#CurrDaily CurrDaily
	full outer join
	#PrevDaily PrevDaily
	on
		CurrDaily.BankChannel = PrevDaily.BankChannel
	full outer join
	#LastYearDaily LastYearDaily
	on
		coalesce(CurrDaily.BankChannel,PrevDaily.BankChannel) = LastYearDaily.BankChannel
order by
	BankName,
	BankChannel;
		

--5. Drop Temporary Tables
drop table #CurrDaily;
drop table #PrevDaily;
drop table #LastYearDaily;

end
	
	

