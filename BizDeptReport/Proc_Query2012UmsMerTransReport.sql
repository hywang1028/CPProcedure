--Created By 王红燕 2012-04-01 报表名称:2012年银商明细总表 
--Input:StartDate，PeriodUnit，EndDate
--Output:分公司,商户代码,商户名称,商户类型,上线时间,一般网上支付(笔数/金额),互联宝(笔数/金额),网上批扣(笔数/金额),便民(笔数/金额),商城(笔数/金额),代付(笔数/金额)
--Modified By 王红燕 2012-04-09 修改原因:将商户开户日期的口径改使用吴迪给出数据
--[Modified] at 2012-07-13 by 王红燕  Description:Add Financial Dept Configuration Data
--[Modified] at 2012-09-07 by 王红燕  Description:根据用户的报表变更需求变更
--[Modified] at 2012-12-13 by 王红燕  Description:Add Branch Office Fund Trans Data
--[Modified] at 2013-06-18 by 丁俊昊  Description:Add Add UpopliqFeeLiq_Data and TraScreenSum Data
if OBJECT_ID(N'Proc_Query2012UmsMerTransReport', N'P') is not null
begin
	drop procedure Proc_Query2012UmsMerTransReport;
end
go
--总交易量
create procedure Proc_Query2012UmsMerTransReport
	@StartDate datetime = '2013-05-01',
	@PeriodUnit nchar(4) = N'月',
	@EndDate datetime = '2012-12-01',
	@TransType nchar(10) = N'总交易量'
as
begin

--1. Check input
if (@StartDate is null or ISNULL(@PeriodUnit, N'') = N''  or (@PeriodUnit = N'自定义' and @EndDate is null))
begin
	raiserror(N'Input params cannot be empty in Proc_Query2012UmsMerTransReport', 16, 1);
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

--3. Prepare All Data
--3.0 Get GateNo Config Data
Create table #GateNo
(
	GateNo char(20) not null
);

if(@TransType = N'总交易量')
begin
    insert into #GateNo
    select
		GateNo
    from
		Table_GateRoute
	union all
	select
		distinct GateNo
	from
		Table_UpopliqFeeLiqResult
	union all
	select
		distinct ChannelNo
	from
		Table_TraScreenSum;
end
else if(@TransType = N'B2C(除UPOP)')
begin
	insert into #GateNo
    select
		GateNo
    from
		Table_GateRoute
	where
		GateNo not in (select GateNo from Table_GateCategory where GateCategory1 in ('B2B','UPOP',N'代扣'));
end
else if(@TransType = N'B2B')
begin
	insert into #GateNo
    select
		GateNo
    from
		Table_GateCategory
	where
		GateCategory1 = 'B2B';
end
else if(@TransType = N'UPOP')
begin
	insert into #GateNo
    select
		GateNo
    from
		Table_GateCategory
	where
		GateCategory1 = 'UPOP'
	union all
	select
		distinct GateNo
	from
		Table_UpopliqFeeLiqResult
end;


--3.1 Prepare Product Trans Data
--3.1.0 Prepare All Payment Data
With ValidPayData as
(
	select 
		Trans.MerchantNo MerchantNo,
		Trans.GateNo GateNo,
		SUM(Trans.SucceedTransCount) as TransCnt,
		SUM(Trans.SucceedTransAmount) as TransAmt
	from
		FactDailyTrans Trans
		inner join
		#GateNo GateNo
		on
			Trans.GateNo = GateNo.GateNo
	where
		Trans.DailyTransDate >= @CurrStartDate
		and
		Trans.DailyTransDate < @CurrEndDate
	group by
		Trans.MerchantNo,
		Trans.GateNo
),
InvalidPayData as
(
	select 
		Trans.DailyTransLog_MerchantNo MerchantNo,
		Trans.DailyTransLog_GateNo GateNo,
		SUM(Trans.DailyTransLog_SucceedTransCount) as TransCnt,
		SUM(Trans.DailyTransLog_SucceedTransAmount) as TransAmt
	from
		Table_InvalidDailyTrans Trans
		inner join
		#GateNo GateNo
		on
			Trans.DailyTransLog_GateNo = GateNo.GateNo
	where
		Trans.DailyTransLog_Date >= @CurrStartDate
		and
		Trans.DailyTransLog_Date < @CurrEndDate
	group by
		Trans.DailyTransLog_MerchantNo,
		Trans.DailyTransLog_GateNo
),
Payment as
(
select
	coalesce(Data.MerchantNo,Invalid.MerchantNo) MerchantNo,
	coalesce(Data.GateNo,Invalid.GateNo) GateNo,
	ISNULL(Data.TransAmt,0)+ISNULL(Invalid.TransAmt,0) TransAmt,
	ISNULL(Data.TransCnt,0)+ISNULL(Invalid.TransCnt,0) TransCnt
from
	ValidPayData Data
	full outer join
	InvalidPayData Invalid
	on
		Data.MerchantNo = Invalid.MerchantNo
		and
		Data.GateNo = Invalid.GateNo
), 
Tra as
(
select
	MerchantNo,
	ChannelNo,
	SUM(CalFeeAmt) TransAmt,
	SUM(CalFeeCnt) TransCnt
from
	Table_TraScreenSum Tra
	inner join
	#GateNo
	on
		Tra.ChannelNo = #GateNo.GateNo
where
	CPDate >= @CurrStartDate
	and
	CPDate < @CurrEndDate
	and
	TransType in ('100001','100004')
group by
	MerchantNo,
	ChannelNo
),
UPOP as
(
	select
		UPOP.MerchantNo,
		UPOP.GateNo,
		SUM(PurAmt) TransAmt,
		SUM(PurCnt) TransCnt
	from
		Table_UpopliqFeeLiqResult UPOP
		inner join
		#GateNo
		on
			UPOP.GateNo = #GateNo.GateNo
	where
		TransDate >= @CurrStartDate
		and
		TransDate < @CurrEndDate
	group by
		UPOP.MerchantNo,
		UPOP.GateNo
)
	select * into  #PaymentData from Payment
	union all
	select * from UPOP
	union all
	select * from Tra;


--3.1.1 Prepare '互联宝' Data
select
	MerchantNo,
	SUM(TransCnt) TransCnt,
	SUM(TransAmt) TransAmt
into
	#EPOSTransData
from
	#PaymentData
where
	GateNo in (select GateNo from Table_GateCategory where GateCategory1 = 'EPOS')
	and
	MerchantNo not in (select MerchantNo from Table_EposTakeoffMerchant)
group by
	MerchantNo;


--3.1.2 Prepare '网上批扣' Data 
select
	#PaymentData.MerchantNo,
	SUM(TransCnt) TransCnt,
	SUM(TransAmt) TransAmt
into
	#DeductTransData
from
	#PaymentData
where
	GateNo in (select GateNo from Table_GateCategory where GateCategory1 = N'代扣')
	or
	GateNo in (select ChannelNo from Table_TraScreenSum where TransType in ('100001','100004'))
group by
	MerchantNo;


--3.1.3 Prepare '便民' Data
With PublicBiz as
(
	select
		MerchantNo,
		SUM(TransCnt) TransCnt,
		SUM(TransAmt) TransAmt
	from
		#PaymentData
	where
		MerchantNo in (select MerchantNo from dbo.Table_InstuMerInfo where InstuNo = '000020100816001')
	group by
		MerchantNo
),
TripBiz as
(
	select
		MerchantNo,
		SUM(TransCnt) TransCnt,
		SUM(TransAmt) TransAmt
	from
		#PaymentData
	where
		MerchantNo in ('808080510003188')
	group by
		MerchantNo
)
select * into #ConvenienceData from PublicBiz
union all
select * from TripBiz;


--3.1.4 Prepare '商城（扣除）' Data
select
	MerchantNo,
	SUM(TransCnt) TransCnt,
	SUM(TransAmt) TransAmt
into
	#EmallTakeOffData
from
	#PaymentData
where
	MerchantNo in ('808080290000007')
group by
	MerchantNo;


--3.1.5 Prepare '商城（上报）' Data
With EmallTransSum as
(
	select
		BranchOffice,
		MerchantName,
		MerchantNo,
		SUM(SucceedTransCount) TransCnt,
		SUM(SucceedTransAmount) TransAmt
	 from
		Table_EmallTransSum
	 where
		TransDate >= @CurrStartDate
		and 
		TransDate <  @CurrEndDate
	 group by
		BranchOffice,
		MerchantName,
		MerchantNo
)
select
	ISNULL(BranchOffice.UmsSpec,N'') as BranchOffice,
	case when BranchOffice.UmsSpec is not null then 0 else 1 End as OrderID,
	EmallTransSum.MerchantNo,
	ISNULL(EmallTransSum.MerchantName,N'') MerchantName,
	N'商城商户' as MerchantType,
	Convert(char(10),EmallMer.OpenTime,120) OpenTime,
	0 as PayTransCnt,
	0 as PayTransAmt,
	0 as EPOSTransCnt,
	0 as EPOSTransAmt,
	0 as DeductTransCnt,
	0 as DeductTransAmt,
	0 as ConvenienceTransCnt,
	0 as ConvenienceTransAmt,
	EmallTransSum.TransCnt/10000.0 as EmallTransCnt,
	EmallTransSum.TransAmt/1000000.0 as EmallTransAmt,
	0 as ORATransCnt,
	0 as ORATransAmt,
	0 as FundTransCnt,
	0 as FundTransAmt
into
	#EmallTransData
from
	EmallTransSum
	left join
	(select 
		*
	 from
		Table_EmallMerInfo 
	 where	
		OpenTime < @CurrEndDate
	)EmallMer
	on
		EmallMer.MerchantNo = EmallTransSum.MerchantNo
	left join
	Table_BranchOfficeNameRule BranchOffice
	on
		EmallTransSum.BranchOffice = BranchOffice.UnnormalBranchOfficeName;


--3.1.6 Prepare '代付类' Data and '新代收付' Data
With ORATransData as
(
	select
		MerchantNo,
		SUM(TransCount) TransCnt,
		SUM(TransAmount) TransAmt
	from
		Table_OraTransSum
	where 
		CPDate >= @CurrStartDate
		and
		CPDate <  @CurrEndDate
	group by
		MerchantNo
	union all
	select
		MerchantNo,
		SUM(CalFeeCnt) TransCnt,
		SUM(CalFeeAmt) TransAmt		
	from
		Table_TraScreenSum
	where
		CPDate >= @CurrStartDate
		and
		CPDate <  @CurrEndDate
		and
		TransType in ('100002','100005')
	group by 
		MerchantNo
),
WUTransData as
(
	select
		MerchantNo,
		COUNT(DestTransAmount) TransCnt,
		SUM(DestTransAmount) TransAmt
	from
		Table_WUTransLog
	where
		CPDate >= @CurrStartDate
		and
		CPDate <  @CurrEndDate
	group by
		MerchantNo
)
	select 
		MerchantNo,
		SUM(TransCnt) TransCnt,
		SUM(TransAmt) TransAmt
	into
		#ORAWUTransData	
	from 
		ORATransData
	group by
		MerchantNo
	union all
	select * from WUTransData;


--3.1.7 Prepare All Trans Data(include UPOP and CupSecure)
With ExistMerInfo as
(
	select * from #EPOSTransData
	union all
	select * from #DeductTransData
	union all
	select * from #ConvenienceData
	union all
	select * from #EmallTakeOffData
),
ExistMerTransData as
(
	select
		MerchantNo,
		SUM(TransCnt) TransCnt,
		SUM(TransAmt) TransAmt
	from
		ExistMerInfo
	group by
		MerchantNo
),
AllMerTrans as
(
	select
		MerchantNo,
		SUM(TransCnt) TransCnt,
		SUM(TransAmt) TransAmt
	from
		#PaymentData
	group by
		MerchantNo
),
AllMerTransData as
(
	select
		MerchantNo,
		SUM(TransCnt) TransCnt,
		SUM(TransAmt) TransAmt
	from
		AllMerTrans
	group by
		MerchantNo
)
select
	AllMer.MerchantNo,
	(AllMer.TransCnt - ISNULL(ExistMer.TransCnt,0)) TransCnt,
	(AllMer.TransAmt - ISNULL(ExistMer.TransAmt,0)) TransAmt
into
	#PaymentTransData
from
	AllMerTransData AllMer
	left join
	ExistMerTransData ExistMer
	on
		AllMer.MerchantNo = ExistMer.MerchantNo;


--3.2.1 Prepare Mer Info Data 
select
	coalesce(PayMer.MerchantNo,OraMer.MerchantNo) CPMerchantNo,
	coalesce(PayMer.MerchantName,OraMer.MerchantName) MerchantName,
	coalesce(PayMer.OpenTime,OraMer.OpenTime) OpenTime
into
	#MerOpenTime
from
	(select * from Table_MerInfo where OpenTime < @CurrEndDate) PayMer
	full outer join
	(select * from Table_OraMerchants where OpenTime < @CurrEndDate) OraMer
	on
		PayMer.MerchantNo = OraMer.MerchantNo;

select 
	Coalesce(#MerOpenTime.CPMerchantNo,Table_TraMerchantInfo.MerchantNo) CPMerchantNo,
	Coalesce(#MerOpenTime.MerchantName,Table_TraMerchantInfo.MerchantName) MerchantName,
	#MerOpenTime.OpenTime
into 
	#MerAndUPOPOpenTime 
from 
	#MerOpenTime
	full join
	Table_TraMerchantInfo
	on
		#MerOpenTime.CPMerchantNo = Table_TraMerchantInfo.MerchantNo
union 
select MerchantNo,MerchantName,null as OpenTime from Table_UpopliqMerInfo;


--3.3 Join All Config Data
With SalesBranchOffice as
(
	select
		Sales.MerchantNo,
		BranchOffice.UmsSpec BranchOffice,
		Mer.IndustryName
	from
		Table_SalesDeptConfiguration Sales
		left join
		Table_BranchOfficeNameRule BranchOffice
		on
			RTRIM(Sales.BranchOffice) = RTRIM(BranchOffice.UnnormalBranchOfficeName)
		left join 
		Table_MerAttribute Mer
		on
			Sales.MerchantNo = Mer.MerchantNo
),
FinanceBranchOffice as
(
	select
		Finance.MerchantNo,
		BranchOffice.UmsSpec BranchOffice,
		Finance.IndustryName
	from
		Table_FinancialDeptConfiguration Finance
		left join
		Table_BranchOfficeNameRule BranchOffice
		on
			RTRIM(Finance.BranchOffice) = RTRIM(BranchOffice.UnnormalBranchOfficeName)
),
MerBranchOffice as
(
	select
		Coalesce(Sales.MerchantNo,Finance.MerchantNo) MerchantNo,
		Coalesce(Sales.BranchOffice,Finance.BranchOffice) BranchOffice,
		Coalesce(Finance.IndustryName,Sales.IndustryName) IndustryName
	from
		SalesBranchOffice Sales
		full outer join
		FinanceBranchOffice Finance
		on
			RTRIM(Sales.MerchantNo) = RTRIM(Finance.MerchantNo)
),
AllTransData as
(
	select
		Mer.CPMerchantNo as AllMerchantNo,
		Mer.MerchantName,
		Mer.OpenTime,
		ISNULL(Pay.TransCnt,0) as PayTransCnt,
		ISNULL(Pay.TransAmt,0) as PayTransAmt,
		ISNULL(EPOS.TransCnt,0) as EPOSTransCnt,
		ISNULL(EPOS.TransAmt,0) as EPOSTransAmt,
		ISNULL(Deduct.TransCnt,0) as DeductTransCnt,
		ISNULL(Deduct.TransAmt,0) as DeductTransAmt,
		ISNULL(Convenience.TransCnt,0) as ConvenienceTransCnt,
		ISNULL(Convenience.TransAmt,0) as ConvenienceTransAmt,
		ISNULL(ORA.TransCnt,0) as ORATransCnt,
		ISNULL(ORA.TransAmt,0) as ORATransAmt
	from
		#MerAndUPOPOpenTime Mer
		full join
		#PaymentTransData Pay
		on
			Mer.CPMerchantNo = Pay.MerchantNo
		full join
		#EPOSTransData EPOS
		on
			Mer.CPMerchantNo = EPOS.MerchantNo
		full join
		#DeductTransData Deduct
		on
			Mer.CPMerchantNo = Deduct.MerchantNo
		full join
		#ConvenienceData Convenience
		on
			Mer.CPMerchantNo = Convenience.MerchantNo
		full join
		#ORAWUTransData ORA
		on
			Mer.CPMerchantNo = ORA.MerchantNo
),
FinalyMer as
(
	select
		AllMerchantNo,
		Table_CpUpopRelation.CpMerNo,
		MerchantName,
		OpenTime,
		PayTransCnt,
		PayTransAmt,
		EPOSTransCnt,
		EPOSTransAmt,
		DeductTransCnt,
		DeductTransAmt,
		ConvenienceTransCnt,
		ConvenienceTransAmt,
		ORATransCnt,
		ORATransAmt
	from
		AllTransData
		left join
		Table_CpUpopRelation
		on
			AllTransData.AllMerchantNo = Table_CpUpopRelation.UpopMerNo
)
select
	ISNULL(MerBranchOffice.BranchOffice,N'') BranchOffice,
	case when MerBranchOffice.BranchOffice is not null then 0 else 1 End as OrderID,
	FinalyMer.AllMerchantNo AllMerchantNo,
	FinalyMer.MerchantName,
	case when
		FinalyMer.AllMerchantNo in (select MerchantNo from Table_UpopliqFeeLiqResult where Table_UpopliqFeeLiqResult.MerchantNo = FinalyMer.AllMerchantNo)
	then
		'UPOP直连'
	else
		coalesce(MerType.MerchantType,N'')
	end
		MerchantType,
	MerBranchOffice.IndustryName,
	case when MerType.OpenAccountDate is not null then Convert(char(10),MerType.OpenAccountDate,120) else N'' End as OpenTime,
	ISNULL(FinalyMer.PayTransCnt,0)/10000.0 PayTransCnt,
	ISNULL(FinalyMer.PayTransAmt,0)/1000000.0 PayTransAmt,
	ISNULL(FinalyMer.EPOSTransCnt,0)/10000.0 EPOSTransCnt,
	ISNULL(FinalyMer.EPOSTransAmt,0)/1000000.0 EPOSTransAmt,
	ISNULL(FinalyMer.DeductTransCnt,0)/10000.0 DeductTransCnt,
	ISNULL(FinalyMer.DeductTransAmt,0)/1000000.0 DeductTransAmt,
	ISNULL(FinalyMer.ConvenienceTransCnt,0)/10000.0 ConvenienceTransCnt,
	ISNULL(FinalyMer.ConvenienceTransAmt,0)/1000000.0 ConvenienceTransAmt,
	0 as EmallTransCnt,
	0 as EmallTransAmt,
	case when @TransType = N'总交易量' then ISNULL(FinalyMer.ORATransCnt,0)/10000.0 Else 0 End as ORATransCnt,
	case when @TransType = N'总交易量' then ISNULL(FinalyMer.ORATransAmt,0)/1000000.0 Else 0 End as ORATransAmt,
	0 as FundTransCnt,
	0 as FundTransAmt
into
	#Result
from
	FinalyMer
	left join
	MerBranchOffice MerBranchOffice
	on
		Coalesce(FinalyMer.CpMerNo,FinalyMer.AllMerchantNo) = MerBranchOffice.MerchantNo
	left join
	Table_MerOpenAccountInfo MerType
	on
		FinalyMer.AllMerchantNo = MerType.MerchantNo;


if(@TransType = N'B2B' or @TransType = 'UPOP')
begin
    select * from #Result order by OrderID,BranchOffice;
end
else if(@TransType = N'B2C(除UPOP)')
begin
	select * from #Result
	union all
	select
			BranchOffice,
			OrderID,
			MerchantNo as AllMerchantNo,
			MerchantName,
			MerchantType,
			N'' as IndustryName,
			OpenTime,
			PayTransCnt,
			PayTransAmt,
			EPOSTransCnt,
			EPOSTransAmt,
			DeductTransCnt,
			DeductTransAmt,
			ConvenienceTransCnt,
			ConvenienceTransAmt,
			EmallTransCnt,
			EmallTransAmt,
			ORATransCnt,
			ORATransAmt,
			FundTransCnt,
			FundTransAmt
		from
			#EmallTransData
	order by OrderID,BranchOffice;	
End
else if(@TransType = N'总交易量')
begin
	select * from #Result
	union all
	select
		BranchOffice,
		OrderID,
		MerchantNo as AllMerchantNo,
		MerchantName,
		MerchantType,
		N'' as IndustryName,
		OpenTime,
		PayTransCnt,
		PayTransAmt,
		EPOSTransCnt,
		EPOSTransAmt,
		DeductTransCnt,
		DeductTransAmt,
		ConvenienceTransCnt,
		ConvenienceTransAmt,
		EmallTransCnt,
		EmallTransAmt,
		ORATransCnt,
		ORATransAmt,
		FundTransCnt,
		FundTransAmt
	from
		#EmallTransData
	union all
	select 
		BranchOfficeNameRule.NormalBranchOfficeName BranchOffice,
		0 as OrderID,
		N'' as AllMerchantNo,
		N'' as MerchantName,
		N'基金' as MerchantType,
		N'' as IndustryName,
		N'' as OpenTime,
		0 as PayTransCnt,
		0 as PayTransAmt,
		0 as EPOSTransCnt,
		0 as EPOSTransAmt,
		0 as DeductTransCnt,
		0 as DeductTransAmt,
		0 as ConvenienceTransCnt,
		0 as ConvenienceTransAmt,
		0 as EmallTransCnt,
		0 as EmallTransAmt,
		0 as ORATransCnt,
		0 as ORATransAmt,
		SUM(Branch.B2BPurchaseCnt+Branch.B2BRedemptoryCnt+Branch.B2CPurchaseCnt+Branch.B2CRedemptoryCnt)/10000.0 FundTransCnt,
		SUM(Branch.B2BPurchaseAmt+Branch.B2BRedemptoryAmt+Branch.B2CPurchaseAmt+Branch.B2CRedemptoryAmt)/1000000.0 FundTransAmt
	from 
		Table_UMSBranchFundTrans Branch
		inner join
		Table_BranchOfficeNameRule BranchOfficeNameRule
		on
			Branch.BranchOfficeName = BranchOfficeNameRule.UnnormalBranchOfficeName
	where	
		Branch.TransDate >= @CurrStartDate
		and
		Branch.TransDate <  @CurrEndDate
	group by
		BranchOfficeNameRule.NormalBranchOfficeName
	order by 
		OrderID,
		BranchOffice;	
end
else if(@TransType = N'其它')
begin
	select 
		BranchOfficeNameRule.NormalBranchOfficeName BranchOffice,
		0 as OrderID,
		N'' as AllMerchantNo,
		N'' as MerchantName,
		N'基金' as MerchantType,
		N'' as OpenTime,
		0 as PayTransCnt,
		0 as PayTransAmt,
		0 as EPOSTransCnt,
		0 as EPOSTransAmt,
		0 as DeductTransCnt,
		0 as DeductTransAmt,
		0 as ConvenienceTransCnt,
		0 as ConvenienceTransAmt,
		0 as EmallTransCnt,
		0 as EmallTransAmt,
		0 as ORATransCnt,
		0 as ORATransAmt,
		SUM(Branch.B2BPurchaseCnt+Branch.B2BRedemptoryCnt+Branch.B2CPurchaseCnt+Branch.B2CRedemptoryCnt)/10000.0 FundTransCnt,
		SUM(Branch.B2BPurchaseAmt+Branch.B2BRedemptoryAmt+Branch.B2CPurchaseAmt+Branch.B2CRedemptoryAmt)/1000000.0 FundTransAmt
	from 
		Table_UMSBranchFundTrans Branch
		inner join
		Table_BranchOfficeNameRule BranchOfficeNameRule
		on
			Branch.BranchOfficeName = BranchOfficeNameRule.UnnormalBranchOfficeName
	where	
		Branch.TransDate >= @CurrStartDate
		and
		Branch.TransDate <  @CurrEndDate
	group by
		BranchOfficeNameRule.NormalBranchOfficeName;	
end


--4. Drop Table
Drop table #GateNo;
Drop Table #PaymentData;
Drop Table #EPOSTransData;
Drop Table #DeductTransData;
Drop Table #ConvenienceData;
Drop Table #EmallTransData;
Drop Table #ORAWUTransData;
Drop Table #EmallTakeOffData;
Drop Table #PaymentTransData;
Drop Table #MerOpenTime;
Drop table #Result;

End

---------------------------------------------------------------------------------
--TEST DATA
-----1.
--select SUM(TransAmt)TransAmt,SUM(TransCnt)TransCnt from #PaymentTransData
--union all
--select SUM(TransAmt)TransAmt,SUM(TransCnt)TransCnt from #EPOSTransData
--union all
--select SUM(TransAmt)TransAmt,SUM(TransCnt)TransCnt from #DeductTransData
--union all
--select SUM(TransAmt)TransAmt,SUM(TransCnt)TransCnt from #ConvenienceData
--union all
--select SUM(TransAmt)TransAmt,SUM(TransCnt)TransCnt from #EmallTakeOffData
--union all
--select  SUM(TransAmt)TransAmt,SUM(TransCnt)TransCnt from #ORAWUTransData 

-----2.
--select
--	SUM(PurAmt)TransAmt,
--	SUM(PurCnt)TransCnt
--from
--	Table_UpopliqFeeLiqResult
--where
--	TransDate >= '2013-05-01'
--	and
--	TransDate < '2013-06-01'
--union all
--select 
--	SUM(SucceedTransAmount) TransAmt,
--	SUM(SucceedTransCount) TransCnt
--from 
--	FactDailyTrans
--where 
--	DailyTransDate >= '2013-05-01'
--	and
--	DailyTransDate < '2013-06-01'
--	--and
--	--GateNo in (select GateNo from Table_GateCategory where GateCategory1 = N'代扣')
--union all
--select 
--	SUM(DailyTransLog_SucceedTransAmount) TransAmt,
--	SUM(DailyTransLog_SucceedTransCount) TransCnt
--from 
--	Table_InvalidDailyTrans
--where 
--	DailyTransLog_Date >= '2013-05-01'
--	and
--	DailyTransLog_Date < '2013-06-01'
--	--and
--	--DailyTransLog_GateNo in (select GateNo from Table_GateCategory where GateCategory1 = N'代扣')
--union all
--select 
--	SUM(TransAmount) TransAmt,
--	SUM(TransCount) TransCnt
--from
--	Table_OraTransSum 
--where 
--	CPDate >= '2013-05-01'
--	and
--	CPDate < '2013-06-01'
--union all
--select 
--	SUM(CalFeeAmt) TransAmt,
--	SUM(CalFeeCnt) TransCnt
--from 
--	Table_TraScreenSum 
--where 
--	CPDate >= '2013-05-01'
--	and
--	CPDate < '2013-06-01'
--union all
--select 
--	SUM(DestTransAmount) TransAmt,
--	COUNT(DestTransAmount) TransCnt	
--from 
--	Table_WUTransLog 
--where
--	CPDate >= '2013-05-01'
--	and
--	CPDate < '2013-06-01'