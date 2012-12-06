--Created By 王红燕 2012-04-01 报表名称:2012年银商明细总表 
--Input:StartDate，PeriodUnit，EndDate
--Output:分公司,商户代码,商户名称,商户类型,上线时间,一般网上支付(笔数/金额),互联宝(笔数/金额),网上批扣(笔数/金额),便民(笔数/金额),商城(笔数/金额),代付(笔数/金额)
--Modified By 王红燕 2012-04-09 修改原因:将商户开户日期的口径改使用吴迪给出数据
--[Modified] at 2012-07-13 by 王红燕  Description:Add Financial Dept Configuration Data
--[Modified] at 2012-09-07 by 王红燕  Description:根据用户的报表变更需求变更
if OBJECT_ID(N'Proc_Query2012UmsMerTransReport', N'P') is not null
begin
	drop procedure Proc_Query2012UmsMerTransReport;
end
go

create procedure Proc_Query2012UmsMerTransReport
	@StartDate datetime = '2012-01-01',
	@PeriodUnit nchar(4) = N'月',
	@EndDate datetime = '2012-02-01',
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
	GateNo char(4) not null
);

if(@TransType = N'总交易量')
begin
    insert into #GateNo
    select
		GateNo
    from
		Table_GateRoute;
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
		GateCategory1 = 'UPOP';
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
)
select
	coalesce(Data.MerchantNo,Invalid.MerchantNo) MerchantNo,
	coalesce(Data.GateNo,Invalid.GateNo) GateNo,
	ISNULL(Data.TransAmt,0)+ISNULL(Invalid.TransAmt,0) TransAmt,
	ISNULL(Data.TransCnt,0)+ISNULL(Invalid.TransCnt,0) TransCnt
into
	#PaymentData
from
	ValidPayData Data
	full outer join
	InvalidPayData Invalid
	on
		Data.MerchantNo = Invalid.MerchantNo
		and
		Data.GateNo = Invalid.GateNo;
		
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
	MerchantNo,
	SUM(TransCnt) TransCnt,
	SUM(TransAmt) TransAmt
into
	#DeductTransData
from
	#PaymentData
where
	GateNo in (select GateNo from Table_GateCategory where GateCategory1 = N'代扣')
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
	0 as ORATransAmt
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

--3.1.6 Prepare '代付类' Data
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
select * into #ORAWUTransData from ORATransData
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
AllMerTransData as
(
	select
		MerchantNo,
		SUM(TransCnt) TransCnt,
		SUM(TransAmt) TransAmt
	from
		#PaymentData
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
	coalesce(PayMer.MerchantNo,OraMer.MerchantNo) MerchantNo,
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
		
--3.3 Join All Config Data
With SalesBranchOffice as
(
	select
		Sales.MerchantNo,
		BranchOffice.UmsSpec BranchOffice
	from
		Table_SalesDeptConfiguration Sales
		left join
		Table_BranchOfficeNameRule BranchOffice
		on
			RTRIM(Sales.BranchOffice) = RTRIM(BranchOffice.UnnormalBranchOfficeName)
),
FinanceBranchOffice as
(
	select
		Finance.MerchantNo,
		BranchOffice.UmsSpec BranchOffice
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
		Coalesce(Sales.BranchOffice,Finance.BranchOffice) BranchOffice
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
		Mer.MerchantNo,
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
		#MerOpenTime Mer
		left join
		#PaymentTransData Pay
		on
			Mer.MerchantNo = Pay.MerchantNo
		left join
		#EPOSTransData EPOS
		on
			Mer.MerchantNo = EPOS.MerchantNo
		left join
		#DeductTransData Deduct
		on
			Mer.MerchantNo = Deduct.MerchantNo
		left join
		#ConvenienceData Convenience
		on
			Mer.MerchantNo = Convenience.MerchantNo
		left join
		#ORAWUTransData ORA
		on
			Mer.MerchantNo = ORA.MerchantNo
)
select
	ISNULL(MerBranchOffice.BranchOffice,N'') BranchOffice,
	case when MerBranchOffice.BranchOffice is not null then 0 else 1 End as OrderID,
	AllTransData.MerchantNo,
	AllTransData.MerchantName,
	coalesce(MerType.MerchantType,N'') MerchantType,
	case when MerType.OpenAccountDate is not null then Convert(char(10),MerType.OpenAccountDate,120) else N'' End as OpenTime,
	ISNULL(AllTransData.PayTransCnt,0)/10000.0 PayTransCnt,
	ISNULL(AllTransData.PayTransAmt,0)/1000000.0 PayTransAmt,
	ISNULL(AllTransData.EPOSTransCnt,0)/10000.0 EPOSTransCnt,
	ISNULL(AllTransData.EPOSTransAmt,0)/1000000.0 EPOSTransAmt,
	ISNULL(AllTransData.DeductTransCnt,0)/10000.0 DeductTransCnt,
	ISNULL(AllTransData.DeductTransAmt,0)/1000000.0 DeductTransAmt,
	ISNULL(AllTransData.ConvenienceTransCnt,0)/10000.0 ConvenienceTransCnt,
	ISNULL(AllTransData.ConvenienceTransAmt,0)/1000000.0 ConvenienceTransAmt,
	0 as EmallTransCnt,
	0 as EmallTransAmt,
	case when @TransType = N'总交易量' then ISNULL(AllTransData.ORATransCnt,0)/10000.0 Else 0 End as ORATransCnt,
	case when @TransType = N'总交易量' then ISNULL(AllTransData.ORATransAmt,0)/1000000.0 Else 0 End as ORATransAmt
into
	#Result
from
	AllTransData
	left join
	MerBranchOffice MerBranchOffice
	on
		AllTransData.MerchantNo = MerBranchOffice.MerchantNo
	left join
	Table_MerOpenAccountInfo MerType
	on
		AllTransData.MerchantNo = MerType.MerchantNo;

if(@TransType = N'B2B' or @TransType = 'UPOP')
begin
    select * from #Result order by OrderID,BranchOffice;
end
else if(@TransType = N'总交易量' or @TransType = N'B2C(除UPOP)')
begin
	select * from #Result
	union all
	select * from #EmallTransData
	order by OrderID,BranchOffice;	
End

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