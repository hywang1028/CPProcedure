--Created By 王红燕 2013-06-06 报表名称:网关投入产出表_子表3_考核版网关成本率与收入率统计
--Input:StartDate，PeriodUnit，EndDate
--Output:考核口径版,平均银行成本率,银行成本占比,平均收入率,收入占比

--Modified By Richard Wu 2013-07-23 Use Proc_GetPaymentCost replace Proc_CalPaymentCost
--Modified By Richard Wu 2013-10-28 Use Proc_CalPaymentCost replace Proc_GetPaymentCost


if OBJECT_ID(N'Proc_QueryPartGateFeeRatioIOReport', N'P') is not null
begin
	drop procedure Proc_QueryPartGateFeeRatioIOReport;
end
go

create procedure Proc_QueryPartGateFeeRatioIOReport
	@StartDate datetime = '2013-01-01',
	@PeriodUnit nchar(4) = N'半年',
	@EndDate datetime = '2013-05-31'
as
begin

--1. Check input
if (@StartDate is null or ISNULL(@PeriodUnit, N'') = N''  or (@PeriodUnit = N'自定义' and @EndDate is null))
begin
	raiserror(N'Input params cannot be empty in Proc_QueryPartGateFeeRatioIOReport', 16, 1);
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
	and
	Ora.BankSettingID in (Select distinct BankSettingID from Table_OraBankCostRule)
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
	where 
		Ora.BankSettingID in (Select distinct BankSettingID from Table_OraBankCostRule)
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

With NoCostRuleGate as
(
	select
		Gate.GateNo
	from
		Table_GateRoute Gate
		left join
		(select distinct GateNo from Table_GateCostRule) GateCost
		on
			Gate.GateNo = GateCost.GateNo
	where
		GateCost.GateNo is null
),
CurrPayTrans as
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
	where
		GateNo not in ('0016','0018','0019','0024','0044','0045','0058','0086','1019','2008',
			'3124','5003','5005','5009','5011','5013','5015','5021','5022','5023','5026','5031','5032','5131','5132',
			'5424','5602','5603','5604','5606','5608','5609','5901','5902','7007','7009','7012','7013','7015','7018',
			'7022','7023','7024','7025','7027','7029','7033','7107','7207','7507','7517','8601','8604','8607','8610','8614','9021')
		and
		GateNo not in (select GateNo from Table_GateCategory where GateCategory1 in ('UPOP','EPOS'))
		and
		GateNo not in (select GateNo from NoCostRuleGate) 		
	group by
		GateNo,
		MerchantNo
),
PayTransData as
(
	select
		CurrPayTrans.GateNo,
		CurrPayTrans.MerchantNo,
		case when Gate.GateCategory1 = 'B2B' then 'B2B'
			 when Gate.GateCategory1 = '代扣' then '代扣'
			 Else N'B2C网银境内' End as BizType,
		CurrPayTrans.TransAmt CurrTransAmt,
		CurrPayTrans.TransCnt CurrTransCnt,
		CurrPayTrans.FeeAmt CurrFeeAmt,
		CurrPayTrans.CostAmt CurrCostAmt
	from
		CurrPayTrans
		left join
		Table_GateCategory Gate
		on
			CurrPayTrans.GateNo = Gate.GateNo
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

End