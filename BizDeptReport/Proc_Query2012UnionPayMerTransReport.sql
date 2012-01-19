if OBJECT_ID(N'Proc_Query2012UnionPayMerTransReport', N'P') is not null
begin
	drop procedure Proc_Query2012UnionPayMerTransReport;
end
go

create procedure Proc_Query2012UnionPayMerTransReport
	@StartDate datetime = '2011-08-01',
	@PeriodUnit nchar(4) = N'月',
	@EndDate datetime = '2011-08-31'
as
begin

--1. Check input
if (@StartDate is null or ISNULL(@PeriodUnit, N'') = N''  or (@PeriodUnit = N'自定义' and @EndDate is null))
begin
	raiserror(N'Input params cannot be empty in Proc_Query2012UnionPayMerTransReport', 16, 1);
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
		DailyTransLog_MerchantNo MerchantNo,
		DailyTransLog_GateNo GateNo,
		SUM(DailyTransLog_SucceedTransCount) as TransCnt,
		SUM(DailyTransLog_SucceedTransAmount) as TransAmt
	from
		Table_InvalidDailyTrans
	where
		DailyTransLog_Date >= @CurrStartDate
		and
		DailyTransLog_Date < @CurrEndDate
	group by
		DailyTransLog_MerchantNo,
		DailyTransLog_GateNo
)
select
	coalesce(Data.MerchantNo,Invalid.MerchantNo) MerchantNo,
	coalesce(Data.GateNo,Invalid.GateNo) GateNo,
	Convert(decimal,(ISNULL(Data.TransAmt,0)+ISNULL(Invalid.TransAmt,0)))/100 TransAmt,
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
		
--3.1.1 Prepare '消费类' Data
select
	MerchantNo,
	SUM(TransCnt) TransCnt,
	SUM(TransAmt)TransAmt
into
	#ConsumeTransData
from
	#PaymentData
where
	GateNo not in (select GateNo from Table_GateCategory where GateCategory1 in('MOTO','CUPSecure','UPOP'))
	and
	GateNo <> '7008'
group by
	MerchantNo;
	
--3.1.2 Prepare '预授权类' Data 
select
	MerchantNo,
	SUM(TransCnt) TransCnt,
	SUM(TransAmt) TransAmt
into
	#MOTOTransData
from
	#PaymentData
where
	GateNo in (select GateNo from Table_GateCategory where GateCategory1 = 'MOTO')
group by
	MerchantNo;

--3.1.3 Prepare '代收类' Data
With ORATransData as
(
	select
		MerchantNo,
		SUM(TransCount) TransCnt,
		CONVERT(decimal,SUM(TransAmount))/100 TransAmt
	from
		Table_OraTransSum
	where 
		CPDate >= @CurrStartDate
		and
		CPDate <  @CurrEndDate
	group by
		MerchantNo
),
Gate7008TransData as
(
	select
		MerchantNo,
		SUM(TransCnt) TransCnt,
		SUM(TransAmt) TransAmt
	from
		#PaymentData
	where
		GateNo = '7008'
	group by
		MerchantNo
),
WUTransData as
(
	select
		MerchantNo,
		COUNT(DestTransAmount) TransCnt,
		CONVERT(decimal,SUM(DestTransAmount))/100 TransAmt
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
union
select * from Gate7008TransData
union
select * from WUTransData;

--3.1.4 Prepare All Trans Data(include UPOP and CupSecure)
With PaymentData as
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
ORAData as
(
	select
		MerchantNo,
		SUM(TransCount) TransCnt,
		CONVERT(decimal,SUM(TransAmount))/100 TransAmt
	from
		Table_OraTransSum
	where 
		CPDate >= @CurrStartDate
		and
		CPDate <  @CurrEndDate
	group by
		MerchantNo
),
WUData as
(
	select
		MerchantNo,
		COUNT(DestTransAmount) TransCnt,
		CONVERT(decimal,SUM(DestTransAmount))/100 TransAmt
	from
		Table_WUTransLog
	where
		CPDate >= @CurrStartDate
		and
		CPDate <  @CurrEndDate
	group by
		MerchantNo
)
select * into #IncludeUPOPCUPData from PaymentData
union
select * from ORAData
union
select * from WUData;

--3.1.5 Join All Product Trans Data 
select
	IUCD.MerchantNo,
	ISNULL(Consume.TransCnt,0) as ConsumeTransCnt,
	ISNULL(Consume.TransAmt,0) as ConsumeTransAmt,
	ISNULL(MOTO.TransCnt,0) as MOTOTransCnt,
	ISNULL(MOTO.TransAmt,0) as MOTOTRansAmt,
	ISNULL(ORA.TransCnt,0) as ORATransCnt,
	ISNULL(ORA.TransAmt,0) as ORATransAmt,
	ISNULL(IUCD.TransCnt,0) as AllTransCnt,
	ISNULL(IUCD.TransAmt,0) as AllTransAmt
into
	#AllTransData
from
	#IncludeUPOPCUPData IUCD
	left join
	#ConsumeTransData Consume
	on
		IUCD.MerchantNo = Consume.MerchantNo
	left join
	#MOTOTransData MOTO
	on
		IUCD.MerchantNo = MOTO.MerchantNo
	left join
	#ORAWUTransData ORA
	on
		IUCD.MerchantNo = ORA.MerchantNo;
		
--3.2 Prepare Configuration Data
--3.2.1 Prepare BranchOffice
With UnionUMSChannel as
(
	select
		coalesce(UnionPay.UnionPaySpec, Sales.BranchOffice) BranchOffice,
		Sales.MerchantName,
		Sales.MerchantNo,
		Sales.IndustryName
	from
		Table_SalesDeptConfiguration Sales
		left join
		Table_BranchOfficeNameRule UnionPay
		on
			Sales.BranchOffice = UnionPay.UnnormalBranchOfficeName
	where
		Sales.Channel in (N'银联', N'银商') 
),
OtherChannel as
(
	select
		ISNULL(BranchOffice.UnionPaySpec,N'') as BranchOffice,
		Sales.MerchantName,
		Sales.MerchantNo,
		Sales.IndustryName
	from 
		Table_SalesDeptConfiguration Sales 
		left join 
		(select distinct 
			BranchOfficeShortName,
			UnionPaySpec 
		from 
			Table_BranchOfficeNameRule 
		where 
			BranchOfficeShortName is not null
		)BranchOffice 
		on 
			Sales.Area = BranchOffice.BranchOfficeShortName 
	where 
		Sales.Channel not in (N'银联',N'银商')
)
select * into #AllBranchOffice from UnionUMSChannel
union 
select * from OtherChannel;

--3.2.2 Join All Mer Trans
select
	ISNULL(BranchOffice.BranchOffice,N'') BranchOffice,
	coalesce(BranchOffice.MerchantNo,Trans.MerchantNo) MerchantNo,
	BranchOffice.MerchantName,	
	BranchOffice.IndustryName,
	ISNULL(Trans.ConsumeTransCnt,0) ConsumeTransCnt,
	ISNULL(Trans.ConsumeTransAmt,0) ConsumeTransAmt,
	ISNULL(Trans.MOTOTransCnt,0) MOTOTransCnt,
	ISNULL(Trans.MOTOTRansAmt,0) MOTOTRansAmt,
	ISNULL(Trans.ORATransCnt,0) ORATransCnt,
	ISNULL(Trans.ORATransAmt,0) ORATransAmt,
	ISNULL(Trans.AllTransCnt,0) AllTransCnt,
	ISNULL(Trans.AllTransAmt,0) AllTransAmt
into
	#AllMerTransData
from
	#AllBranchOffice BranchOffice
	full outer join
	#AllTransData Trans
	on
		BranchOffice.MerchantNo = Trans.MerchantNo;

--3.2.3 Join All Config Data
select
	AllMerTrans.BranchOffice,
	AllMerTrans.MerchantNo,
	coalesce(AllMerTrans.MerchantName,PayMer.MerchantName,ORAMer.MerchantName) MerchantName,
	N'88020000' as InstuNo,
	case when ISNULL(Industry.UnionPayIndustryName,N'')=N'' and ISNULL(AllMerTrans.IndustryName,N'')=N'' then N'未配置'
		 when ISNULL(Industry.UnionPayIndustryName,N'')=N'' and ISNULL(AllMerTrans.IndustryName,N'')<>N'' then N'其它'
		 when ISNULL(Industry.UnionPayIndustryName,N'')<>N'' then Industry.UnionPayIndustryName
	End as UnionPayIndustryName,	
	ISNULL(AllMerTrans.IndustryName,N'未配置') SalesIndustryName,
	ISNULL(Convert(char(10),coalesce(PayMer.OpenTime,ORAMer.OpenTime),120),N'') MerOpenAccountDate,
	ISNULL(AllMerTrans.ConsumeTransCnt,0) ConsumeTransCnt,
	ISNULL(AllMerTrans.ConsumeTransAmt,0) ConsumeTransAmt,
	ISNULL(AllMerTrans.MOTOTransCnt,0) MOTOTransCnt,
	ISNULL(AllMerTrans.MOTOTRansAmt,0) MOTOTRansAmt,
	ISNULL(AllMerTrans.ORATransCnt,0) ORATransCnt,
	ISNULL(AllMerTrans.ORATransAmt,0) ORATransAmt,
	ISNULL(AllMerTrans.AllTransCnt,0) AllTransCnt,
	ISNULL(AllMerTrans.AllTransAmt,0) AllTransAmt
from
	#AllMerTransData AllMerTrans
	left join
	Table_MerInfo PayMer
	on
		AllMerTrans.MerchantNo = PayMer.MerchantNo
	left join
	Table_OraMerchants ORAMer
	on
		AllMerTrans.MerchantNo = ORAMer.MerchantNo
	left join
	Table_IndustryNameRule Industry
	on
		AllMerTrans.IndustryName = Industry.UnnormalIndustryName
order by
	BranchOffice DESC;	

--4. Drop Table
Drop Table #ConsumeTransData;
Drop Table #MOTOTransData;
Drop Table #ORAWUTransData;
Drop Table #PaymentData;
Drop Table #IncludeUPOPCUPData;
Drop Table #AllTransData;
Drop Table #AllBranchOffice;
Drop Table #AllMerTransData;

End