--[Modified] at 2013-07-22 by 丁俊昊 Description:Add FeeAmtData and CostAmtData
--[Modified] at 2013-08-29 by 丁俊昊 Description:Finaly Result Need Get All CPMerchantNo from Table_InstuMerInfo
--[Modified] at 2013-10-09 by 丁俊昊 Description:Add Stat Limit and No GateNo
--[Modified] at 2013-11-27 by 丁俊昊 Description:Add New GateNo(7607) Data
if OBJECT_ID(N'Proc_QueryPayMobilePhoneReport',N'P') is not null
begin
	drop procedure Proc_QueryPayMobilePhoneReport;
end
go

create procedure Proc_QueryPayMobilePhoneReport
	@StartDate date,
	@PeriodUnit nchar(3),
	@EndDate date
as
begin

--1.
--目的：检查时间参数是否为空
--结果集：报错信息
--粒度：无
--列名：无
if(@StartDate is null or isnull(@PeriodUnit, N'')=N'')
begin
	raiserror(N'@StartDate and @PeriodUnit cannot be empty.',16,1);  
end

declare @CurrStartDate date;
declare @CurrEndDate date;

if(@PeriodUnit = N'周')  
begin  
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(WEEK,1,@StartDate);
end  
else if(@PeriodUnit = N'月')  
begin  
	set @CurrStartDate = @StartDate;  
	set @CurrEndDate = DATEADD(MONTH,1,@StartDate);  
end  
else if(@PeriodUnit = N'季度')  
begin  
	set @CurrStartDate = @StartDate;  
	set @CurrEndDate = DATEADD(QUARTER,1,@StartDate);  
end  
else if(@PeriodUnit = N'半年')  
begin  
	set @CurrStartDate = @StartDate;  
	set @CurrEndDate = DATEADD(MONTH,6,@StartDate);  
end  
else if(@PeriodUnit = N'年')  
begin  
	set @CurrStartDate = @StartDate;  
	set @CurrEndDate = DATEADD(YEAR,1,@StartDate);  
end  
else if(@PeriodUnit = N'自定义')  
begin
	if(@EndDate is null)
	begin
		raiserror(N'@EndDate cannot be empty.',16,1);  
	end
	
	if(@EndDate < @StartDate)
	begin
		raiserror(N'@EndDate cannot earlier than @StartDate.', 16, 1);
	end
	
	set @CurrStartDate = @StartDate;  
	set @CurrEndDate = DATEADD(day,1,@EndDate);  
end;  


--1.1
--目的：准备成本数据和收入数据的统计计算
--结果集：#UPOPCostAndFeeData  
--粒度：网关号、商户号  
--列名：GateNo、MerchantNo、TransDate、CdFlag、TransAmt、TransCnt、FeeAmt、CostAmt
create table #UPOPCostAndFeeData
(
	GateNo char(4),
	MerchantNo varchar(25),
	TransDate date,
	CdFlag	char(2),
	TransAmt decimal(16,2),
	TransCnt bigint,
	FeeAmt decimal(16,2),
	CostAmt decimal(16,2)
);

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
	@CurrEndDate;

--2.  
--目的：999920130320153机构号下所有CP商户号对应用户配置表中的UPOP商户号。  
--结果集：#InstuNoMer  
--粒度：商户号  
--列名：CPMerchantNo、UpopMerNo  
with InstuNo as  
(  
	select  
		MerchantNo  
	from  
		Table_InstuMerInfo  
	where  
		InstuNo = '999920130320153'
		and
		Stat = '1'
)
select
	InstuNo.MerchantNo,
	Table_CpUpopRelation.UpopMerNo
into
	#InstuNoMer
from
	InstuNo
	left join
	Table_CpUpopRelation
	on
		InstuNo.MerchantNo = Table_CpUpopRelation.CpMerNo;

--
select
	MerchantNo,
	sum(SucceedTransAmount) as TransAmt,
	sum(SucceedTransCount) as TransCnt
into
	#Gate7607
from
	FactDailyTrans
where
	GateNo = '7607'
	and
	DailyTransDate >= @CurrStartDate
	and
	DailyTransDate < @CurrEndDate
group by
	MerchantNo;

with upop as
(
	select
		MerchantNo,
		SUM(TransAmt) as TransAmt,
		SUM(TransCnt) as TransCnt,
		SUM(FeeAmt) as FeeAmt,
		SUM(CostAmt) as CostAmt
	from
		#UPOPCostAndFeeData
	group by
		MerchantNo
)
select
	instu.MerchantNo as CPMerchantNo,
	merinfo.MerchantName as CPMerchantName,
	instu.UpopMerNo as UpopMerNo,
	(select MerchantName from Table_UpopliqMerInfo where MerchantNo = instu.UpopMerNo) as UpopMerchantName,
	merinfo.OpenTime,
	ISNULL(upop.TransAmt,0)/1000000.0 as UpopTransAmt,
	ISNULL(upop.TransCnt,0)/10000.0 as UpopTransCnt,
	ISNULL(upop.FeeAmt,0)/100.0 as UpopFeeAmt,
	ISNULL(upop.CostAmt,0)/100.0 as UpopCostAmt,
	ISNULL(g.TransAmt,0)/1000000.0 as TransAmt,
	ISNULL(g.TransCnt,0)/10000.0 as TransCnt,
	(ISNULL(upop.TransAmt, 0) + ISNULL(g.TransAmt, 0))/1000000.0 as AllTransAmt,
	(ISNULL(upop.TransCnt, 0) + ISNULL(g.TransCnt, 0))/10000.0 as AllTransCnt
from
	#InstuNoMer instu
	left join
	Table_MerInfo merinfo
	on
		instu.MerchantNo = merinfo.MerchantNo
	left join
	upop
	on
		instu.UpopMerNo = upop.MerchantNo
	left join
	#Gate7607 g
	on
		instu.MerchantNo = g.MerchantNo


--Drop table
drop table #UPOPCostAndFeeData;
drop table #InstuNoMer;
drop table #Gate7607;



end