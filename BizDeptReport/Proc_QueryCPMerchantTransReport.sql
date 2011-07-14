if OBJECT_ID(N'Proc_QueryCPMerchantTransReport', N'P') is not null
begin
	drop procedure Proc_QueryCPMerchantTransReport;
end
go

create procedure Proc_QueryCPMerchantTransReport
	@StartDate as datetime = '2011-02-01',
	@EndDate as datetime = '2011-02-28',
	@BizCategory as nchar(10) = '消费类'
as
begin

--1. Check input
	if (@StartDate is null or @EndDate is null or ISNULL(@BizCategory,N'') = N'')
	begin
		raiserror(N'Input params cannot be empty in Proc_QueryCPMerchantTransReport', 16, 1);
	end;
	
--2. Prepare task
--2.1 Prepare @EndDate
	set @EndDate = DATEADD(day,1,@EndDate);

--2.2 Get DailyTrans during the period
--2.2.1 Create Table #PeriodSumValue
Create Table #PeriodSumValue
(
	MerchantNo char(20) not null,
	SucceedCount int not null,
	SucceedAmount Decimal(12,2) not null
);
 if(@BizCategory = N'消费类')
 begin
	insert into #PeriodSumValue
	(
		MerchantNo,
		SucceedCount,
		SucceedAmount
	)
	select
		Trans.MerchantNo,
	    SUM(Trans.SucceedTransCount) AS SucceedCount,
		Convert(Decimal,SUM(Trans.SucceedTransAmount))/100 AS SucceedAmount
	from
		FactDailyTrans Trans
		inner join 
		DimGate
		on 
			Trans.GateID = DimGate.GateID
	where
		Trans.DailyTransDate >= @StartDate
		and
		Trans.DailyTransDate < @EndDate
		and
		DimGate.GateNo not in ('5003', '5005', '5009', '5022', '5026', '5015','5023', '5021', '7008','0044','0045')
	group by
		Trans.MerchantNo;
 end
 else if (@BizCategory = N'订购类')
  begin
    insert into #PeriodSumValue
    (
		MerchantNo,
		SucceedCount,
		SucceedAmount
	)
	select
		Trans.MerchantNo,
	    SUM(Trans.SucceedTransCount) AS SucceedCount,
		Convert(Decimal,SUM(Trans.SucceedTransAmount))/100 AS SucceedAmount
	from
		FactDailyTrans Trans
		inner join 
		DimGate
		on 
			Trans.GateID = DimGate.GateID
	where
		Trans.DailyTransDate >= @StartDate
		and
		Trans.DailyTransDate < @EndDate
		and
		DimGate.GateNo in ('5003', '5005', '5009', '5022', '5026', '5015', '5021','5023')
	group by
		Trans.MerchantNo;
 end	
else if(@BizCategory = N'代收类')
  begin
	insert into #PeriodSumValue
	(
		MerchantNo,
		SucceedCount,
		SucceedAmount
	)
	select
		Trans.MerchantNo,
	    SUM(Trans.SucceedTransCount) AS SucceedCount,
		Convert(Decimal,SUM(Trans.SucceedTransAmount))/100 AS SucceedAmount
	from
		FactDailyTrans Trans
		inner join 
		DimGate
		on 
			Trans.GateID = DimGate.GateID
	where
		Trans.DailyTransDate >= @StartDate
		and
		Trans.DailyTransDate < @EndDate
		and
		DimGate.GateNo in ('7008')
	group by
		Trans.MerchantNo;
end
else if(@BizCategory = N'基金定投类')
  begin
	insert into #PeriodSumValue
	(
		MerchantNo,
		SucceedCount,
		SucceedAmount
	)
	select
		Trans.MerchantNo,
	    SUM(Trans.SucceedTransCount) AS SucceedCount,
		Convert(Decimal,SUM(Trans.SucceedTransAmount))/100 AS SucceedAmount
	from
		FactDailyTrans Trans
		inner join 
		DimGate
		on 
			Trans.GateID = DimGate.GateID
	where
		Trans.DailyTransDate >= @StartDate
		and
		Trans.DailyTransDate < @EndDate
		and
		DimGate.GateNo in ('0044','0045')
	group by
		Trans.MerchantNo;
 end

--3. Get Result
select
	Merchant.MerchantNo,
	Merchant.MerchantName,
	ISNULL(PeriodSumValue.SucceedCount,0) AS SucceedCount,
	ISNULL(PeriodSumValue.SucceedAmount,0) AS SucceedAmount
from
	dbo.DimMerchant Merchant
	inner join
	#PeriodSumValue PeriodSumValue
	on
		Merchant.MerchantNo = PeriodSumValue.MerchantNo
where
	PeriodSumValue.SucceedCount > 0
order by
	Merchant.MerchantID,
	Merchant.MerchantName;
		
--4. Clear temp table
drop table #PeriodSumValue;

end