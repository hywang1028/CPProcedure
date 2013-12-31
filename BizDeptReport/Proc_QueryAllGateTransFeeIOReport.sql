--Created By 王红燕 2013-06-05 报表名称:网关投入产出表_子表1_全网关交易量统计
--Input:StartDate，PeriodUnit，EndDate
--Output:全网关列表,网关名称,业务类型,交易金额（亿元）,占比,交易笔数（万笔）,占比,收入（万元）,占比,收入率,银行成本（万元）,占比,银行成本率

--Modified By Richard Wu 2013-07-23 Use Proc_GetPaymentCost replace Proc_CalPaymentCost
--Modified By 王红燕 2013-12-31 Use Proc_CalPaymentCost replace Proc_GetPaymentCost

if OBJECT_ID(N'Proc_QueryAllGateTransFeeIOReport', N'P') is not null
begin
	drop procedure Proc_QueryAllGateTransFeeIOReport;
end
go

create procedure Proc_QueryAllGateTransFeeIOReport
	@StartDate datetime = '2013-01-01',
	@PeriodUnit nchar(4) = N'月',
	@EndDate datetime = '2013-01-31'
as
begin

--1. Check input
if (@StartDate is null or ISNULL(@PeriodUnit, N'') = N''  or (@PeriodUnit = N'自定义' and @EndDate is null))
begin
	raiserror(N'Input params cannot be empty in Proc_QueryAllGateTransFeeIOReport', 16, 1);
end

--2. Prepare StartDate and EndDate
declare @CurrStartDate datetime;
declare @CurrEndDate datetime;

if(@PeriodUnit = N'月')
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
    set @CurrEndDate = DateAdd(day,1,@EndDate);
end;

--Current Pay Trans
create table #CurrPayCost
(
	GateNo char(4) not null,
	MerchantNo char(20) not null,
	FeeEndDate datetime not null,
	TransSumCount bigint not null,
	TransSumAmount bigint not null,
	Cost decimal(15,4) not null,
	FeeAmt decimal(15,2) not null,
	InstuFeeAmt decimal(15,2) not null
);
insert into 
	#CurrPayCost
exec 
	Proc_CalPaymentCost @CurrStartDate,@CurrEndDate,NULL,'on';
	
--Current UPOP Liq Trans
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
insert into #UPOPCostAndFeeData
exec Proc_CalUPOPCost @CurrStartDate,@CurrEndDate;

--Current Ora Trans
create table #CurrOraCost
(
	BankSettingID char(10) not null,
	MerchantNo char(20) not null,
	CPDate datetime not null,
	TransCnt bigint not null,
	TransAmt bigint not null,
	CostAmt decimal(15,4) not null
);
insert into 
	#CurrOraCost
exec 
	Proc_CalOraCost @CurrStartDate,@CurrEndDate,NULL;

select
	Ora.MerchantNo,
	Ora.BankSettingID,
	SUM(Ora.TransCount) TransCnt,
	SUM(Ora.FeeAmount) FeeAmt
into	
	#CurrOraFee
from
	Table_OraTransSum Ora
where
	Ora.CPDate >= @CurrStartDate
	and
	Ora.CPDate <  @CurrEndDate
group by
	Ora.MerchantNo,
	Ora.BankSettingID;

update
	Ora
set
	Ora.FeeAmt = MerRate.FeeValue * Ora.TransCnt
from
	#CurrOraFee Ora
	inner join
	Table_OraAdditionalFeeRule MerRate
	on
		Ora.MerchantNo = MerRate.MerchantNo;
			
With OraFee as
(
	select
		Ora.BankSettingID,
		SUM(Ora.FeeAmt) FeeAmt
	from
		#CurrOraFee Ora
	group by
		Ora.BankSettingID
),
OraCost as
(
	select
		Ora.BankSettingID,
		SUM(Ora.TransCnt) TransCnt,
		SUM(Ora.TransAmt) TransAmt,
		SUM(Ora.CostAmt) CostAmt
	from
		#CurrOraCost Ora
	group by
		Ora.BankSettingID
)
select
	OraCost.BankSettingID,
	OraCost.TransAmt,
	OraCost.TransCnt,
	OraCost.CostAmt,
	OraFee.FeeAmt
into
	#CurrOraTrans
from
	OraCost
	inner join
	OraFee
	on
		OraCost.BankSettingID = OraFee.BankSettingID;
	
With CurrPayTrans as
(
	select
		GateNo,
		SUM(TransSumAmount) TransAmt,
		SUM(TransSumCount) TransCnt,
		SUM(FeeAmt) FeeAmt,
		SUM(Cost) CostAmt
	from
		#CurrPayCost
	group by
		GateNo
),
UpopLiqFee as
(
	select
		GateNo,
		SUM(PurCnt) TransCnt,
		SUM(PurAmt) TransAmt,
		SUM(FeeAmt) FeeAmt
	from
		Table_UpopliqFeeLiqResult
	where
		TransDate >= @CurrStartDate
		and
		TransDate < @CurrEndDate
	group by
		GateNo
),
UpopLiqCost as
(
	select 
		GateNo,
		SUM(CostAmt) CostAmt
	from 
		#UPOPCostAndFeeData
	group by
		GateNo
),
AllTransData as
(
	select
		CurrPayTrans.GateNo,
		ISNULL(Gate.GateCategory1,N'B2C') as BizType,
		ISNULL(CurrPayTrans.TransAmt,0) CurrTransAmt,
		ISNULL(CurrPayTrans.TransCnt,0) CurrTransCnt,
		ISNULL(CurrPayTrans.FeeAmt,0) CurrFeeAmt,
		ISNULL(CurrPayTrans.CostAmt,0) CurrCostAmt
	from
		CurrPayTrans
		left join
		Table_GateCategory Gate
		on
			CurrPayTrans.GateNo = Gate.GateNo
	union all
	select
		CurrOraTrans.BankSettingID as GateNo,
		N'代付' as BizType,
		ISNULL(CurrOraTrans.TransAmt,0) CurrTransAmt,
		ISNULL(CurrOraTrans.TransCnt,0) CurrTransCnt,
		ISNULL(CurrOraTrans.FeeAmt,0) CurrFeeAmt,
		ISNULL(CurrOraTrans.CostAmt,0) CurrCostAmt
	from
		#CurrOraTrans CurrOraTrans
	union all
	select
		GateNo,
		N'B2C' as BizType,
		ISNULL(SUM(SucceedTransAmount),0) as CurrTransAmt,
		ISNULL(SUM(SucceedTransCount),0) as CurrTransCnt,
		0 as CurrFeeAmt,
		0 as CurrCostAmt
	from
		FactDailyTrans
	where
		DailyTransDate >= @CurrStartDate
		and
		DailyTransDate <  @CurrEndDate
		and
		GateNo in ('0044','0045')
	group by
		GateNo
	union all
	select
		UpopLiqFee.GateNo,
		N'UPOP直连' as BizType,
		UpopLiqFee.TransAmt CurrTransAmt,
		UpopLiqFee.TransCnt CurrTransCnt,
		UpopLiqFee.FeeAmt CurrFeeAmt,
		UpopLiqCost.CostAmt CurrCostAmt
	from
		UpopLiqFee
		inner join
		UpopLiqCost	
		on
			UpopLiqFee.GateNo = UpopLiqCost.GateNo
),
TransSumData as
(
	select
		SUM(ISNULL(CurrTransAmt,0)) CurrTransAmtSum,
		SUM(ISNULL(CurrTransCnt,0)) CurrTransCntSum,
		SUM(ISNULL(CurrFeeAmt,0)) CurrFeeAmtSum,
		SUM(ISNULL(CurrCostAmt,0)) CurrCostAmtSum
	from
		AllTransData
),
TempResult as
(
	select
		AllTransData.GateNo,
		COALESCE(Gate.GateDesc,Ora.BankName,Upop.GateDesc) as BankName,
		case when AllTransData.BizType = 'UPOP' then N'UPOP间连' 
			 Else AllTransData.BizType
		End as BizType,
		AllTransData.CurrTransAmt CurrTransAmt,
		AllTransData.CurrTransCnt CurrTransCnt,
		AllTransData.CurrFeeAmt CurrFeeAmt,
		AllTransData.CurrCostAmt CurrCostAmt,
		case when BizType <> N'UPOP直连' and coalesce(GateCost.GateNo,OraCost.BankSettingID) is null then -1 
			 Else 0 
		End as CurrCostFlag
	from
		AllTransData
		left join
		Table_GateRoute Gate
		on
			AllTransData.GateNo = Gate.GateNo
		left join
		Table_OraBankSetting Ora
		on
			AllTransData.GateNo = Ora.BankSettingID
		left join
		Table_UpopliqGateRoute Upop
		on
			AllTransData.GateNo = Upop.GateNo
		left join
		(select distinct GateNo from Table_GateCostRule)GateCost
		on
			AllTransData.GateNo = GateCost.GateNo
		left join
		(Select distinct BankSettingID from Table_OraBankCostRule)OraCost
		on
			AllTransData.GateNo = OraCost.BankSettingID
)
select
	TempResult.GateNo,
	TempResult.BankName,
	TempResult.BizType,
	TempResult.CurrCostFlag,
	Convert(decimal,TempResult.CurrTransAmt)/10000000000.0 as CurrTransAmt,
	case when TransSumData.CurrTransAmtSum = 0 then NULL
		 Else Convert(decimal,TempResult.CurrTransAmt)/TransSumData.CurrTransAmtSum End as TransAmtOccuRatio,
	Convert(decimal,TempResult.CurrTransCnt)/10000.0 as CurrTransCnt,
	case when TransSumData.CurrTransCntSum = 0 then NULL
		 Else Convert(decimal,TempResult.CurrTransCnt)/TransSumData.CurrTransCntSum End as TransCntOccuRatio,
	Convert(decimal,TempResult.CurrFeeAmt)/1000000.0 as CurrFeeAmt,
	case when TransSumData.CurrFeeAmtSum = 0 then NULL
		 Else Convert(decimal,TempResult.CurrFeeAmt)/TransSumData.CurrFeeAmtSum End as FeeAmtOccuRatio,
	case when BizType in ('B2B',N'代扣',N'代付') 
	 then case when TempResult.CurrTransCnt = 0 
			   then 0 
	      Else Convert(decimal,TempResult.CurrFeeAmt)/(100*TempResult.CurrTransCnt) End
	 Else case when TempResult.CurrTransAmt = 0 
			   then 0 
	      Else Convert(decimal,TempResult.CurrFeeAmt)/TempResult.CurrTransAmt End
	End as FeeAmtRatio,
	Convert(decimal,TempResult.CurrCostAmt)/1000000.0 as CurrCostAmt,
	case when TransSumData.CurrCostAmtSum = 0 then NULL
		 Else Convert(decimal,TempResult.CurrCostAmt)/TransSumData.CurrCostAmtSum End as CostAmtOccuRatio,
	case when BizType in ('B2B',N'代扣',N'代付') 
	 then case when TempResult.CurrTransCnt = 0 
			   then 0 
	      Else Convert(decimal,TempResult.CurrCostAmt)/(100*TempResult.CurrTransCnt) End
	 Else case when TempResult.CurrTransAmt = 0 
			   then 0 
	      Else Convert(decimal,TempResult.CurrCostAmt)/TempResult.CurrTransAmt End
	End as CostAmtRatio
from
	TempResult,TransSumData
order by
	TempResult.BizType,
	TempResult.GateNo;

-- Drop table 
drop table #CurrPayCost;
drop table #CurrOraCost;
drop table #CurrOraFee;
drop table #CurrOraTrans;

End