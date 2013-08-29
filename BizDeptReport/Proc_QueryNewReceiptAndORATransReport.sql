--[Modified] on 2013-05-10 By 丁俊昊 Description:Add West Union Trans Data
--[Modified] on 2013-05-24 By 丁俊昊 Description:Modified FeeAmt and CostAmt
if OBJECT_ID(N'Proc_QueryNewReceiptAndORATransReport',N'p')is not null
begin
	drop procedure Proc_QueryNewReceiptAndORATransReport
end
go

create procedure Proc_QueryNewReceiptAndORATransReport
	@StartDate datetime = '2013-05-01',
	@EndDate datetime = '2013-05-31',
	@BizType nvarchar(5) = N'全部',
	@PeriodUnit nchar(5) = N'自定义'
as
begin


--1.check input
if (@StartDate is null or ISNULL(@PeriodUnit, N'') = N''  or (@PeriodUnit = N'自定义' and @EndDate is null) or @BizType is null)
begin
	raiserror(N'Input params cannot be empty in Proc_QueryNewReceiptAndORATransReport',16,1);
end


--2. Prepare StartDate and EndDate
declare @CurrStartDate datetime;
declare @CurrEndDate datetime;

if(@PeriodUnit = N'周')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(week, 1, @StartDate);
end
else if(@PeriodUnit = N'月')
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
    set @CurrEndDate = DATEADD(day,1,@EndDate);
end


--2.1 Prepare TransType
create table #TransType
(
	TransType varchar(20)
);

if @BizType = N'代付'
begin
	insert into #TransType
	values
		('100002'),
		('100005');
end
else if @BizType = N'代收'
begin
	insert into #TransType
	values
		('100001'),
		('100004');
end
else
begin
	insert into #TransType
	values
		('100002'),
		('100005'),
		('100001'),
		('100004');;
end


--3. Prepare CalTraCost Data
create table #CalTraCost
	(	
		MerchantNo char(15),
		ChannelNo char(6),	
		TransType varchar(20),	
		CPDate date,
		TotalCnt int,	
		TotalAmt decimal(15,2),	
		SucceedCnt int,	
		SucceedAmt decimal(15,2),	
		CalFeeCnt int,	
		CalFeeAmt decimal(15,2),	
		CalCostCnt int,	
		CalCostAmt decimal(15,2),	
		FeeAmt decimal(15,2),
		CostAmt decimal(15,2)
	)
begin
	insert into #CalTraCost
	(	
		MerchantNo,
		ChannelNo,	
		TransType,	
		CPDate,
		TotalCnt,	
		TotalAmt,	
		SucceedCnt,	
		SucceedAmt,	
		CalFeeCnt,	
		CalFeeAmt,	
		CalCostCnt,	
		CalCostAmt,	
		FeeAmt,
		CostAmt
	)
	exec Proc_CalTraCost
		@CurrStartDate,
		@CurrEndDate
end;


--3.1 Prepare FinalyData
select
	MerchantNo,
	(select MerchantName from Table_TraMerchantInfo where MerchantNo = #CalTraCost.MerchantNo) as MerchantName,
	SUM(CalFeeAmt)/1000000.0 CalFeeAmt,
	SUM(CalFeeCnt)/10000.0 CalFeeCnt,
	SUM(FeeAmt)/100.0 FeeAmt,
	SUM(CostAmt)/100.0 CostAmt
from
	#CalTraCost
where 
	TransType in (select																									
						TransType
					from
						#TransType)
group by
	MerchantNo;


drop table #TransType;

end


