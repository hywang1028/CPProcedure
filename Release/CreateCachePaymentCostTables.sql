--Created At 2013-07-09 By Richard Wu
--Cached CalPaymentCost

if OBJECT_ID(N'Table_CachePaymentCost', N'U') is null
begin
	create table Table_CachePaymentCost
	(
		GateNo char(4),
		MerchantNo char(15),
		FeeEndDate date,
		TransCnt int,
		TransAmt decimal(14,2),
		CostAmt decimal(14,4),
		FeeAmt decimal(14,2),
		InstuFeeAmt decimal(14,2),
		primary key (FeeEndDate,MerchantNo,GateNo)
	)
end


if OBJECT_ID(N'Table_CachePaymentCostLog', N'U') is null
begin
	create table Table_CachePaymentCostLog
	(
		LogId int identity(1,1) primary key,
		StartDate date,
		EndDate date,
		HisRefDate date,
		ConvertToRMB char(2),
		CacheAction varchar(20),
		CreatedAt datetime default(getdate())
	)
end

