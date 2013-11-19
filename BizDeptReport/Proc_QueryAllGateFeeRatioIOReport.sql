--Created By 王红燕 2013-06-05 报表名称:网关投入产出表_子表2_全网关成本率与收入率统计
--Input:StartDate，PeriodUnit，EndDate
--Output:全网关版,平均银行成本率,银行成本占比,平均收入率,收入占比

--Modified By Richard Wu 2013-07-23 Use Proc_GetPaymentCost replace Proc_CalPaymentCost
--Modified By Richard Wu 2013-10-28 Use Proc_CalPaymentCost replace Proc_GetPaymentCost

if OBJECT_ID(N'Proc_QueryAllGateFeeRatioIOReport', N'P') is not null
begin
	drop procedure Proc_QueryAllGateFeeRatioIOReport;
end
go

create procedure Proc_QueryAllGateFeeRatioIOReport
	@StartDate datetime = '2013-05-01',
	@PeriodUnit nchar(4) = N'月',
	@EndDate datetime = '2013-05-31'
as
begin

--1. Check input
if (@StartDate is null or ISNULL(@PeriodUnit, N'') = N''  or (@PeriodUnit = N'自定义' and @EndDate is null))
begin
	raiserror(N'Input params cannot be empty in Proc_QueryAllGateFeeRatioIOReport', 16, 1);
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
	Ora.MerchantNo;

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
		SUM(Ora.FeeAmt) FeeAmt
	from
		#CurrOraFee Ora
),
OraCost as
(
	select
		SUM(Ora.TransCnt) TransCnt,
		SUM(Ora.TransAmt) TransAmt,
		SUM(Ora.CostAmt) CostAmt
	from
		#CurrOraCost Ora
)
select
	OraCost.TransAmt,
	OraCost.TransCnt,
	OraCost.CostAmt,
	OraFee.FeeAmt
into
	#CurrOraTrans
from
	OraCost,
	OraFee;

With CurrPayTrans as
(
	select
		GateNo,
		MerchantNo,
		SUM(TransSumAmount) TransAmt,
		SUM(TransSumCount) TransCnt,
		SUM(FeeAmt) FeeAmt,
		SUM(Cost) CostAmt
	from
		#CurrPayCost
	group by
		GateNo,
		MerchantNo
	union all
	select
		GateNo,
		MerchantNo,
		ISNULL(SUM(SucceedTransAmount),0) as TransAmt,
		ISNULL(SUM(SucceedTransCount),0) as TransCnt,
		0 as FeeAmt,
		0 as CostAmt
	from
		FactDailyTrans
	where
		DailyTransDate >= @CurrStartDate
		and
		DailyTransDate <  @CurrEndDate
		and
		GateNo in ('0044','0045')
	group by
		GateNo,
		MerchantNo
),
PayTransData as
(
	select
		CurrPayTrans.GateNo,
		CurrPayTrans.MerchantNo,
		case when Gate.GateCategory1 = 'UPOP' then 'UPOP间连'
			 when Gate.GateCategory1 = 'EPOS' then 'EPOS'
			 when CurrPayTrans.GateNo in ('5901','5902') then '接入'
			 when Gate.GateCategory1 = 'B2B' then 'B2B'
			 when Gate.GateCategory1 = '代扣' then '代扣'
			 Else N'B2C网银境内' End as BizType,
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
),
UpopLiqFee as
(
	select
		SUM(PurCnt) TransCnt,
		SUM(PurAmt) TransAmt,
		SUM(FeeAmt) FeeAmt
	from
		Table_UpopliqFeeLiqResult
	where
		TransDate >= @CurrStartDate
		and
		TransDate < @CurrEndDate
),
UpopLiqCost as
(
	select 
		SUM(CostAmt) CostAmt
	from 
		#UPOPCostAndFeeData
),
AllTransData as
(
	select
		N'B2C网银境外' as BizType,
		ISNULL(SUM(CurrTransAmt),0) CurrTransAmt,
		ISNULL(SUM(CurrTransCnt),0) CurrTransCnt,
		ISNULL(SUM(CurrFeeAmt),0) CurrFeeAmt,
		ISNULL(SUM(CurrCostAmt),0) CurrCostAmt
	from
		PayTransData
	where
		MerchantNo in (select MerchantNo from Table_MerInfoExt)
	union all
	select
		BizType,
		ISNULL(SUM(CurrTransAmt),0) CurrTransAmt,
		ISNULL(SUM(CurrTransCnt),0) CurrTransCnt,
		ISNULL(SUM(CurrFeeAmt),0) CurrFeeAmt,
		ISNULL(SUM(CurrCostAmt),0) CurrCostAmt
	from
		PayTransData
	where
		MerchantNo not in (select MerchantNo from Table_MerInfoExt)
	group by
		BizType
	union all
	select
		N'代付' as BizType,
		ISNULL(CurrOraTrans.TransAmt,0) CurrTransAmt,
		ISNULL(CurrOraTrans.TransCnt,0) CurrTransCnt,
		ISNULL(CurrOraTrans.FeeAmt,0) CurrFeeAmt,
		ISNULL(CurrOraTrans.CostAmt,0) CurrCostAmt
	from
		#CurrOraTrans CurrOraTrans
	union all
	select
		N'UPOP直连' as BizType,
		UpopLiqFee.TransAmt CurrTransAmt,
		UpopLiqFee.TransCnt CurrTransCnt,
		UpopLiqFee.FeeAmt CurrFeeAmt,
		UpopLiqCost.CostAmt CurrCostAmt
	from
		UpopLiqFee,
		UpopLiqCost	
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
)
select
	AllTransData.BizType,
	case when BizType in ('B2B',N'代扣',N'代付') 
	 then case when AllTransData.CurrTransCnt = 0 
			   then 0 
	      Else Convert(decimal,AllTransData.CurrCostAmt)/(100.0*AllTransData.CurrTransCnt) End
	 Else case when AllTransData.CurrTransAmt = 0 
			   then 0 
	      Else Convert(decimal,AllTransData.CurrCostAmt)/AllTransData.CurrTransAmt End
	End as CostAmtRatio,
	case when TransSumData.CurrCostAmtSum = 0 then NULL
		 Else AllTransData.CurrCostAmt/TransSumData.CurrCostAmtSum 
	End as CostAmtOccuRatio,
	case when BizType in ('B2B',N'代扣',N'代付') 
	 then case when AllTransData.CurrTransCnt = 0 
			   then 0 
	      Else Convert(decimal,AllTransData.CurrFeeAmt)/(100.0*AllTransData.CurrTransCnt) End
	 Else case when AllTransData.CurrTransAmt = 0 
			   then 0 
	      Else Convert(decimal,AllTransData.CurrFeeAmt)/AllTransData.CurrTransAmt End
	End as FeeAmtRatio,
	case when TransSumData.CurrFeeAmtSum = 0 then NULL
		 Else AllTransData.CurrFeeAmt/TransSumData.CurrFeeAmtSum 
	End as FeeAmtOccuRatio,
	TransSumData.CurrCostAmtSum,
	TransSumData.CurrFeeAmtSum	
from
	AllTransData,TransSumData
order by
	AllTransData.BizType;

-- Drop table 
drop table #CurrPayCost;
drop table #CurrOraCost;
drop table #CurrOraFee;
drop table #CurrOraTrans;
drop table #UPOPCostAndFeeData;
End