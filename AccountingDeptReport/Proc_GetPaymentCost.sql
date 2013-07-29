--Created At 2013-07-09 By Richard Wu
--Cached CalPaymentCost

--Modified At 2013-07-29 By Richard Wu
--@EndDate cannot larger than yesterday, since Table_FeeCalResult(FeeEndDate) T-2

if OBJECT_ID(N'Proc_GetPaymentCost', N'P') is not null
begin
	drop procedure Proc_GetPaymentCost
end
go

create procedure Proc_GetPaymentCost
	@StartDate datetime,  
	@EndDate datetime,  
	@HisRefDate datetime = null,  
	@ConvertToRMB char(2) = null,
	@Reset char(2) = null
as
begin

--1. Check input
if(@StartDate is null or @EndDate is null or @StartDate >= @EndDate)  
begin  
	raiserror(N'Invalid StartDate and EndDate input',16,1);  
end

if @EndDate > dateadd(day, -1, GETDATE())
begin
	set @EndDate = dateadd(day, -1, GETDATE())
end

--2. Get latest Table_CachePaymentCostLog record info
declare @latestStartDate date;
declare @latestEndDate date;
declare @latestHisRefDate date;
declare @latestConvertToRMB char(2);

select
	@latestStartDate = StartDate,
	@latestEndDate = EndDate,
	@latestHisRefDate = HisRefDate,
	@latestConvertToRMB = ConvertToRMB
from
	Table_CachePaymentCostLog
where
	LogId >= All(select LogId from Table_CachePaymentCostLog);

--3. Direct get result from Table_CachePaymentCost
if (@StartDate >= @latestStartDate
	and @EndDate <= @latestEndDate
	and isnull(@HisRefDate, '') = isnull(@latestHisRefDate, '')
	and isnull(@ConvertToRMB, '') = isnull(@latestConvertToRMB, '')
	and isnull(@Reset, '') != 'on')
begin
	goto Final_Result;
end
--4. Insert early records into Table_CachePaymentCost
else if (@StartDate < @latestStartDate
	and @EndDate <= @latestEndDate
	and @EndDate >= @latestStartDate
	and isnull(@HisRefDate, '') = isnull(@latestHisRefDate, '')
	and isnull(@ConvertToRMB, '') = isnull(@latestConvertToRMB, '')
	and isnull(@Reset, '') != 'on')
begin
	insert into
		Table_CachePaymentCost
		(
			GateNo,
			MerchantNo,
			FeeEndDate,
			TransCnt,
			TransAmt,
			CostAmt,
			FeeAmt,
			InstuFeeAmt
		)
	exec Proc_CalPaymentCost
		@StartDate,
		@latestStartDate,
		@HisRefDate,
		@ConvertToRMB;
		
	insert into
		Table_CachePaymentCostLog
		(
			StartDate,
			EndDate,
			HisRefDate,
			ConvertToRMB,
			CacheAction
		)
	values
		(
			@StartDate,
			@latestEndDate,
			@HisRefDate,
			@ConvertToRMB,
			'Insert'
		);
end
--5. Insert late records into Table_CachePaymentCost
else if (@StartDate >= @latestStartDate
	and @StartDate <= @latestEndDate
	and @EndDate > @latestEndDate
	and isnull(@HisRefDate, '') = isnull(@latestHisRefDate, '')
	and isnull(@ConvertToRMB, '') = isnull(@latestConvertToRMB, '')
	and isnull(@Reset, '') != 'on')
begin
	insert into
		Table_CachePaymentCost
		(
			GateNo,
			MerchantNo,
			FeeEndDate,
			TransCnt,
			TransAmt,
			CostAmt,
			FeeAmt,
			InstuFeeAmt
		)
	exec Proc_CalPaymentCost
		@latestEndDate,
		@EndDate,
		@HisRefDate,
		@ConvertToRMB;
		
	insert into
		Table_CachePaymentCostLog
		(
			StartDate,
			EndDate,
			HisRefDate,
			ConvertToRMB,
			CacheAction
		)
	values
		(
			@latestStartDate,
			@EndDate,
			@HisRefDate,
			@ConvertToRMB,
			'Insert'
		);
end
--6. Reset Table_CachePaymentCost records
else
begin
	truncate table Table_CachePaymentCost;
	
	insert into
		Table_CachePaymentCost
		(
			GateNo,
			MerchantNo,
			FeeEndDate,
			TransCnt,
			TransAmt,
			CostAmt,
			FeeAmt,
			InstuFeeAmt
		)
	exec Proc_CalPaymentCost
		@StartDate,
		@EndDate,
		@HisRefDate,
		@ConvertToRMB;
		
	insert into
		Table_CachePaymentCostLog
		(
			StartDate,
			EndDate,
			HisRefDate,
			ConvertToRMB,
			CacheAction
		)
	values
		(
			@StartDate,
			@EndDate,
			@HisRefDate,
			@ConvertToRMB,
			'Reset'
		);
end

--7. Select final result
Final_Result:
	select
		GateNo,
		MerchantNo,
		FeeEndDate,
		TransCnt,
		TransAmt,
		CostAmt,
		FeeAmt,
		InstuFeeAmt		
	from
		Table_CachePaymentCost
	where
		FeeEndDate >= @StartDate
		and
		FeeEndDate < @EndDate;

end

