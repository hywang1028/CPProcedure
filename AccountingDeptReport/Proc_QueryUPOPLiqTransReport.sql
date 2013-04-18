--[Create] At 20130327 By 丁俊昊：UPOP直连交易量报表
--Input:StartDate,EndDate
--Output:GateNo,MerchantNo,MerchantName,PurCnt,PurAmt
if OBJECT_ID(N'Proc_QueryUPOPLiqTransReport',N'P') is not null
begin
	drop procedure Proc_QueryUPOPLiqTransReport;
end
go

create procedure Proc_QueryUPOPLiqTransReport
	@StartDate datetime = '2011-01-01',
	@EndDate datetime = '2013-03-01'
as 
begin

--1.Check Input
if(@StartDate is null or @EndDate is null)
begin
	raiserror(N'Input params can`t be empty in Proc_QueryUPOPLiqTransReport',16,1);
end

declare @CurrStartDate datetime;
declare @CurrEndDate datetime;
set @CurrStartDate = @StartDate;
set @CurrEndDate = DATEADD(DAY,1,@EndDate);

--1.2 Ready Cost and Fee
create table #UPOPCostAndFeeData
	(
		GateNo char(6),
		MerchantNo varchar(25),
		TransDate datetime,
		CdFlag	char(5),
		TransAmt decimal(16,2),
		TransCnt bigint,
		FeeAmt decimal(16,2),
		CostAmt decimal(18,4)
	)
begin
	insert into #UPOPCostAndFeeData
	(	
		GateNo,
		MerchantNo,
		TransDate,
		CdFlag,
		TransAmt,
		TransCnt,
		FeeAmt,
		CostAmt
	)
	exec Proc_CalUPOPCost
		@CurrStartDate,
		@CurrEndDate
end


--2.Select UPOPData
select
	GateNo,
	UPOP.MerchantNo,
	UPOPName.MerchantName,
	SUM(PurCnt) PurCnt,
	SUM(PurAmt) PurAmt,
	SUM(FeeAmt) FeeAmt
into
	#FinalyData
from
	Table_UpopliqFeeLiqResult UPOP
	left join
	Table_UpopliqMerInfo UPOPName
	on
		UPOP.MerchantNo = UPOPName.MerchantNo
where
	TransDate >= @CurrStartDate
	and
	TransDate < @CurrEndDate
group by
	GateNo,
	UPOP.MerchantNo,
	UPOPName.MerchantName;


--3.Select UPOPCost
select 
	GateNo,
	MerchantNo,
	SUM(CostAmt) CostAmt
into
	#CostAndFeeData
from 
	#UPOPCostAndFeeData
group by 
	GateNo,
	MerchantNo


--4.结果集
select
	#FinalyData.GateNo,
	#FinalyData.MerchantNo,
	#FinalyData.MerchantName,
	#FinalyData.PurCnt/10000.0 PurCnt,
	#FinalyData.PurAmt/1000000.0 PurAmt,
	#FinalyData.FeeAmt/100.0 FeeAmt,
	#CostAndFeeData.CostAmt/100.0 CostAmt
from
	#FinalyData
	left join
	#CostAndFeeData
	on
		#FinalyData.GateNo = #CostAndFeeData.GateNo
		and
		#FinalyData.MerchantNo = #CostAndFeeData.MerchantNo
end;




--测试
--exec Proc_QueryUPOPLiqTransReport @StartDate = '2011-01-01',@EndDate = '2013-03-12'

--select SUM(CostAmt)/1000000.0 from #CostAndFeeData  where MerchantNo = '802080290000015'