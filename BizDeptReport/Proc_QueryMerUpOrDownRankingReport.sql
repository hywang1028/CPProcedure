--Created By 丁俊昊 2013-08-21 报表名称: 商户异动情况表
--Input: StartDate,EndDate,CompareStartDate,CompareEndDate,UpOrDown,BizType,TopNum
--Output: 商户号、商户名、本周期成功金额、上周期成功金额、上周期成功笔数、交易异动金额、交易异动比、
--Modified By 丁俊昊 2013-09-11 Add AllType in @BizType

if OBJECT_ID(N'Proc_QueryMerUpOrDownRanking',N'p')is not null
begin
	drop procedure Proc_QueryMerUpOrDownRanking;
end
go

create procedure Proc_QueryMerUpOrDownRanking
	@StartDate datetime = '2013-07-11',
	@EndDate datetime = '2013-07-31',
	@CompareStartDate datetime = '2013-06-11',
	@CompareEndDate datetime = '2013-06-30',
	@UpOrDown Nvarchar(8) = '上涨',
	@BizType Nvarchar(8) = N'代付',
	@TopNum as smallint = 50
as
begin


--0.check input
if (@StartDate is null or @EndDate is null or @CompareStartDate is null or @CompareEndDate is null or @UpOrDown is null  or @BizType is null or @TopNum is null)
begin
	raiserror(N'Input params cannot be empty in Proc_QueryMerUpOrDownRanking',16,1);
end


--0.1 Prepare @CurrStartDate and @CurrEndDate etc
declare	@CurrStartDate datetime;
declare	@CurrEndDate datetime;
declare	@PrevStartDate datetime;
declare	@PrevEndDate datetime;
set @CurrStartDate = @StartDate;
set @CurrEndDate = DATEADD(DAY,1,@EndDate);
set @PrevStartDate = @CompareStartDate;
set @PrevEndDate = DATEADD(DAY,1,@CompareEndDate);


Create table #TempMerTrans 
(
	MerchantNo Varchar(40),
	MerchantName Nvarchar(50),
	TransAmt decimal(18,2),
	TransCnt bigint,
	CompareTransCnt bigint,
	CompareTransAmt decimal(18,2),
	UpDataORDown decimal(18,2)
);


--1. Get B2C Data
if(@BizType = 'B2C')
begin
	with AllData as
	(
	select
		FactDailyTrans.MerchantNo,
		SUM(SucceedTransAmount) TransAmt,
		SUM(SucceedTransCount) TransCnt
	from
		FactDailyTrans
	where 
		DailyTransDate >= @CurrStartDate
		and
		DailyTransDate < @CurrEndDate
		and
		GateNo not in (select GateNo from Table_GateCategory where GateCategory1 in ('B2B','EPOS','代扣'))
		and
		GateNo not in ('5901','5902')
		and
		FactDailyTrans.MerchantNo <> '808080510003188'
		and
		FactDailyTrans.MerchantNo <> '808080290000007'
		and
		FactDailyTrans.MerchantNo not in (select MerchantNo from dbo.Table_InstuMerInfo where InstuNo = '000020100816001')
	group by
		FactDailyTrans.MerchantNo
	union all
	select
		FactDailyTrans.MerchantNo,
		SUM(SucceedTransAmount) TransAmt,
		SUM(SucceedTransCount) TransCnt
	from
		FactDailyTrans
	where 
		DailyTransDate >= @CurrStartDate
		and
		DailyTransDate < @CurrEndDate
		and
		GateNo in (select GateNo from Table_GateCategory where GateCategory1 = 'EPOS')
		and
		FactDailyTrans.MerchantNo in (select MerchantNo from Table_EposTakeoffMerchant)
	group by
		FactDailyTrans.MerchantNo
	)
		select
			AllData.MerchantNo,
			SUM(AllData.TransAmt) TransAmt,
			SUM(AllData.TransCnt) TransCnt
		into
			#B2CData
		from
			AllData
		group by
			AllData.MerchantNo;


	with CuryRate as  
	(  
		select  
			CuryCode,  
			AVG(CuryRate) AVGCuryRate   
		from  
			Table_CuryFullRate  
		where  
			CuryDate >= @CurrStartDate
			and  
			CuryDate < @CurrEndDate
		group by  
			CuryCode
	)
	UPDATE
		#B2CData
	SET
		#B2CData.TransAmt = ISNULL(CuryRate.AVGCuryRate,1.0) * #B2CData.TransAmt
	FROM
		#B2CData
		inner join
		Table_MerInfoExt
		on
			#B2CData.MerchantNo = Table_MerInfoExt.MerchantNo
		inner join
		CuryRate
		on
			Table_MerInfoExt.CuryCode = CuryRate.CuryCode;


	--1.2 Get CompareB2C Data
	with AllData as
	(
	select
		FactDailyTrans.MerchantNo,
		SUM(SucceedTransAmount) TransAmt,
		SUM(SucceedTransCount) TransCnt
	from
		FactDailyTrans
	where 
		DailyTransDate >= @PrevStartDate
		and
		DailyTransDate < @PrevEndDate
		and
		GateNo not in (select GateNo from Table_GateCategory where GateCategory1 in ('B2B','EPOS','代扣'))
		and
		GateNo not in ('5901','5902')
		and
		FactDailyTrans.MerchantNo <> '808080510003188'
		and
		FactDailyTrans.MerchantNo <> '808080290000007'
		and
		FactDailyTrans.MerchantNo not in (select MerchantNo from dbo.Table_InstuMerInfo where InstuNo = '000020100816001')
	group by
		FactDailyTrans.MerchantNo
	union all
	select
		FactDailyTrans.MerchantNo,
		SUM(SucceedTransAmount) TransAmt,
		SUM(SucceedTransCount) TransCnt
	from
		FactDailyTrans
	where 
		DailyTransDate >= @PrevStartDate
		and
		DailyTransDate < @PrevEndDate
		and
		GateNo in (select GateNo from Table_GateCategory where GateCategory1 = 'EPOS')
		and
		FactDailyTrans.MerchantNo in (select MerchantNo from Table_EposTakeoffMerchant)
	group by
		FactDailyTrans.MerchantNo
	)
		select
			AllData.MerchantNo,
			SUM(AllData.TransAmt) TransAmt,
			SUM(AllData.TransCnt) TransCnt
		into
			#CompareB2CData
		from
			AllData
		group by
			AllData.MerchantNo;

	with CuryRate as  
	(  
		select  
			CuryCode,  
			AVG(CuryRate) AVGCuryRate   
		from  
			Table_CuryFullRate  
		where  
			CuryDate >= @PrevStartDate
			and  
			CuryDate < @PrevEndDate
		group by  
			CuryCode
	)
	UPDATE
		#CompareB2CData
	SET
		#CompareB2CData.TransAmt = ISNULL(CuryRate.AVGCuryRate,1.0) * #CompareB2CData.TransAmt
	FROM
		#CompareB2CData
		inner join
		Table_MerInfoExt
		on
			#CompareB2CData.MerchantNo = Table_MerInfoExt.MerchantNo
		inner join
		CuryRate
		on
			Table_MerInfoExt.CuryCode = CuryRate.CuryCode;


	with FinalyData as
	(
		select
			coalesce(#B2CData.MerchantNo,#CompareB2CData.MerchantNo) as MerchantNo,
			ISNULL(#B2CData.TransAmt,0) as TransAmt,
			ISNULL(#B2CData.TransCnt,0) as TransCnt,
			ISNULL(#CompareB2CData.TransCnt,0) as CompareTransCnt,
			ISNULL(#CompareB2CData.TransAmt,0) as CompareTransAmt,
			(ISNULL(#B2CData.TransAmt,0)) - (ISNULL(#CompareB2CData.TransAmt,0)) as UpDataORDown
		from
			#B2CData
			full join
			#CompareB2CData
			on
				#B2CData.MerchantNo = #CompareB2CData.MerchantNo
	)
		insert into #TempMerTrans
		select
			FinalyData.MerchantNo,
			Table_MerInfo.MerchantName,
			FinalyData.TransAmt/100.0 TransAmt,
			FinalyData.TransCnt,
			FinalyData.CompareTransCnt,
			FinalyData.CompareTransAmt/100.0 CompareTransAmt,
			FinalyData.UpDataORDown/100.0 UpDataORDown
		from
			FinalyData
			left join
			Table_MerInfo
			on
				FinalyData.MerchantNo = Table_MerInfo.MerchantNo;

drop table #B2CData;
drop table #CompareB2CData;

end
else if(@BizType = 'B2B')
begin
	select
		FactDailyTrans.MerchantNo,
		SUM(SucceedTransAmount) TransAmt,
		SUM(SucceedTransCount) TransCnt
	into
		#B2BData
	from
		FactDailyTrans
	where 
		DailyTransDate >= @CurrStartDate
		and
		DailyTransDate < @CurrEndDate
		and
		GateNo in (select GateNo from Table_GateCategory where GateCategory1 = 'B2B')
	group by
		FactDailyTrans.MerchantNo;

	with CuryRate as  
	(  
		select  
			CuryCode,  
			AVG(CuryRate) AVGCuryRate   
		from  
			Table_CuryFullRate  
		where  
			CuryDate >= @CurrStartDate
			and  
			CuryDate < @CurrEndDate
		group by  
			CuryCode
	)
	UPDATE
		#B2BData
	SET
		#B2BData.TransAmt = ISNULL(CuryRate.AVGCuryRate,1.0) * #B2BData.TransAmt
	FROM
		#B2BData
		inner join
		Table_MerInfoExt
		on
			#B2BData.MerchantNo = Table_MerInfoExt.MerchantNo
		inner join
		CuryRate
		on
			Table_MerInfoExt.CuryCode = CuryRate.CuryCode;


	--1.2 Get CompareB2B Data
	select
		FactDailyTrans.MerchantNo,
		SUM(SucceedTransAmount) TransAmt,
		SUM(SucceedTransCount) TransCnt
	into
		#CompareB2BData
	from
		FactDailyTrans
	where 
		DailyTransDate >= @PrevStartDate
		and
		DailyTransDate < @PrevEndDate
		and
		GateNo in (select GateNo from Table_GateCategory where GateCategory1 = 'B2B')
	group by
		FactDailyTrans.MerchantNo;

	with CuryRate as  
	(  
		select  
			CuryCode,  
			AVG(CuryRate) AVGCuryRate   
		from  
			Table_CuryFullRate  
		where  
			CuryDate >= @PrevStartDate
			and  
			CuryDate < @PrevEndDate
		group by  
			CuryCode
	)
	UPDATE
		#CompareB2BData
	SET
		#CompareB2BData.TransAmt = ISNULL(CuryRate.AVGCuryRate,1.0) * #CompareB2BData.TransAmt
	FROM
		#CompareB2BData
		inner join
		Table_MerInfoExt
		on
			#CompareB2BData.MerchantNo = Table_MerInfoExt.MerchantNo
		inner join
		CuryRate
		on
			Table_MerInfoExt.CuryCode = CuryRate.CuryCode;


	--TempResult
	with FinalyData as
	(
		select
			coalesce(#B2BData.MerchantNo,#CompareB2BData.MerchantNo) as MerchantNo,
			ISNULL(#B2BData.TransAmt,0) as TransAmt,
			ISNULL(#B2BData.TransCnt,0) as TransCnt,
			ISNULL(#CompareB2BData.TransCnt,0) as CompareTransCnt,
			ISNULL(#CompareB2BData.TransAmt,0) as CompareTransAmt,
			(ISNULL(#B2BData.TransAmt,0)) - (ISNULL(#CompareB2BData.TransAmt,0)) as UpDataORDown
		from
			#B2BData
			full join
			#CompareB2BData
			on
				#B2BData.MerchantNo = #CompareB2BData.MerchantNo
	)
		insert into #TempMerTrans
		select
			FinalyData.MerchantNo,
			Table_MerInfo.MerchantName,
			FinalyData.TransAmt/100.0 TransAmt,
			FinalyData.TransCnt,
			FinalyData.CompareTransCnt,
			FinalyData.CompareTransAmt/100.0 CompareTransAmt,
			FinalyData.UpDataORDown/100.0 UpDataORDown
		from
			FinalyData
			left join
			Table_MerInfo
			on
				FinalyData.MerchantNo = Table_MerInfo.MerchantNo;
				
drop table #B2BData;
drop table #CompareB2BData;
end

else if(@BizType = '代收')
begin
	with AllDaiShouData as
	(
		select
			FactDailyTrans.MerchantNo,
			SUM(SucceedTransAmount) TransAmt,
			SUM(SucceedTransCount) TransCnt
		from
			FactDailyTrans
		where 
			DailyTransDate >= @CurrStartDate
			and
			DailyTransDate < @CurrEndDate
			and
			GateNo in (select GateNo from Table_GateCategory where GateCategory1 in ('代扣'))
		group by
			FactDailyTrans.MerchantNo
		union all
		select
			MerchantNo,
			SUM(CalFeeAmt) TransAmt,
			SUM(CalFeeCnt) TransCnt
		from
			Table_TraScreenSum
		where
			TransType in ('100001','100004')
			and
			CPDate >= @CurrStartDate
			and
			CPDate < @CurrEndDate
		group by
			MerchantNo
	)
		select
			MerchantNo,
			SUM(TransAmt) TransAmt,
			SUM(TransCnt) TransCnt
		into
			#DaiShouData
		from
			AllDaiShouData
		group by
			MerchantNo;
	
	with CuryRate as  
	(  
		select  
			CuryCode,  
			AVG(CuryRate) AVGCuryRate   
		from  
			Table_CuryFullRate  
		where  
			CuryDate >= @CurrStartDate 
			and  
			CuryDate <  @CurrEndDate
		group by  
			CuryCode
	)
	UPDATE
		#DaiShouData
	SET
		#DaiShouData.TransAmt = ISNULL(CuryRate.AVGCuryRate,1.0) * #DaiShouData.TransAmt
	FROM
		#DaiShouData
		inner join
		Table_MerInfoExt
		on
			#DaiShouData.MerchantNo = Table_MerInfoExt.MerchantNo
		inner join
		CuryRate
		on
			Table_MerInfoExt.CuryCode = CuryRate.CuryCode;
	
	
	--Get Compare Data
	with AllDaiShouData as
	(
		select
			FactDailyTrans.MerchantNo,
			SUM(SucceedTransAmount) TransAmt,
			SUM(SucceedTransCount) TransCnt
		from
			FactDailyTrans
		where 
			DailyTransDate >= @PrevStartDate
			and
			DailyTransDate < @PrevEndDate
			and
			GateNo in (select GateNo from Table_GateCategory where GateCategory1 in ('代扣'))
		group by
			FactDailyTrans.MerchantNo
		union all
		select
			MerchantNo,
			SUM(CalFeeAmt) TransAmt,
			SUM(CalFeeCnt) TransCnt
		from
			Table_TraScreenSum
		where
			TransType in ('100001','100004')
			and
			CPDate >= @PrevStartDate
			and
			CPDate < @PrevEndDate
		group by
			MerchantNo
	)
		select
			MerchantNo,
			SUM(TransAmt) TransAmt,
			SUM(TransCnt) TransCnt
		into
			#CompareDaiShouData
		from
			AllDaiShouData
		group by
			MerchantNo;
	
	
	with CuryRate as  
	(  
		select  
			CuryCode,  
			AVG(CuryRate) AVGCuryRate   
		from  
			Table_CuryFullRate  
		where  
			CuryDate >= @PrevStartDate 
			and  
			CuryDate <  @PrevEndDate
		group by  
			CuryCode
	)
	UPDATE
		#CompareDaiShouData
	SET
		#CompareDaiShouData.TransAmt = ISNULL(CuryRate.AVGCuryRate,1.0) * #CompareDaiShouData.TransAmt
	FROM
		#CompareDaiShouData
		inner join
		Table_MerInfoExt
		on
			#CompareDaiShouData.MerchantNo = Table_MerInfoExt.MerchantNo
		inner join
		CuryRate
		on
			Table_MerInfoExt.CuryCode = CuryRate.CuryCode;
	

	--TempResult
	with FinalyData as
	(
		select
			coalesce(#DaiShouData.MerchantNo,#CompareDaiShouData.MerchantNo) as MerchantNo,
			ISNULL(#DaiShouData.TransAmt,0) as TransAmt,
			ISNULL(#DaiShouData.TransCnt,0) as TransCnt,
			ISNULL(#CompareDaiShouData.TransCnt,0) as CompareTransCnt,
			ISNULL(#CompareDaiShouData.TransAmt,0) as CompareTransAmt,
			(ISNULL(#DaiShouData.TransAmt,0)) - (ISNULL(#CompareDaiShouData.TransAmt,0)) as UpDataORDown
		from
			#DaiShouData
			full join
			#CompareDaiShouData
			on
				#DaiShouData.MerchantNo = #CompareDaiShouData.MerchantNo
	)
		insert into #TempMerTrans
		select
			FinalyData.MerchantNo,
			Table_MerInfo.MerchantName,
			FinalyData.TransAmt/100.0 TransAmt,
			FinalyData.TransCnt,
			FinalyData.CompareTransCnt,
			FinalyData.CompareTransAmt/100.0 CompareTransAmt,
			FinalyData.UpDataORDown/100.0 UpDataORDown
		from
			FinalyData
			left join
			Table_MerInfo
			on
				FinalyData.MerchantNo = Table_MerInfo.MerchantNo;	

drop table #DaiShouData;
drop table #CompareDaiShouData;
end

else if(@BizType = '代付')
begin
	with AllORAData as
	(
		select
			MerchantNo,
			SUM(TransAmount) TransAmt,
			SUM(TransCount) TransCnt
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
			SUM(CalFeeAmt) TransAmt,
			SUM(CalFeeCnt) TransCnt
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
	)
		select
			MerchantNo,
			SUM(TransAmt) TransAmt,
			SUM(TransCnt) TransCnt
		into
			#ORAData
		from
			AllORAData
		group by
			MerchantNo;
	
	
	--Get Compare Data
	with AllORAData as
	(
		select
			MerchantNo,
			SUM(TransAmount) TransAmt,
			SUM(TransCount) TransCnt
		from
			Table_OraTransSum
		where 
			CPDate >= @PrevStartDate
			and
			CPDate <  @PrevEndDate
		group by
			MerchantNo
		union all
		select
			MerchantNo,
			SUM(CalFeeAmt) TransAmt,
			SUM(CalFeeCnt) TransCnt
		from
			Table_TraScreenSum
		where
			CPDate >= @PrevStartDate
			and
			CPDate <  @PrevEndDate
			and
			TransType in ('100002','100005')
		group by 
			MerchantNo
	)
		select
			MerchantNo,
			SUM(TransAmt) TransAmt,
			SUM(TransCnt) TransCnt
		into
			#CompareORAData
		from
			AllORAData
		group by
			MerchantNo;
	
	
	--TempResult
	with FinalyData as
	(
		select
			coalesce(#ORAData.MerchantNo,#CompareORAData.MerchantNo) as MerchantNo,
			ISNULL(#ORAData.TransAmt,0) as TransAmt,
			ISNULL(#ORAData.TransCnt,0) as TransCnt,
			ISNULL(#CompareORAData.TransCnt,0) as CompareTransCnt,
			ISNULL(#CompareORAData.TransAmt,0) as CompareTransAmt,
			(ISNULL(#ORAData.TransAmt,0)) - (ISNULL(#CompareORAData.TransAmt,0)) as UpDataORDown
		from
			#ORAData
			full join
			#CompareORAData
			on
				#ORAData.MerchantNo = #CompareORAData.MerchantNo
	)
		insert into #TempMerTrans
		select
			FinalyData.MerchantNo,
			coalesce(Table_OraMerchants.MerchantName,Table_TraMerchantInfo.MerchantName) MerchantName,
			FinalyData.TransAmt/100.0 TransAmt,
			FinalyData.TransCnt,
			FinalyData.CompareTransCnt,
			FinalyData.CompareTransAmt/100.0 CompareTransAmt,
			FinalyData.UpDataORDown/100.0 UpDataORDown
		from
			FinalyData
			left join
			Table_OraMerchants
			on
				FinalyData.MerchantNo = Table_OraMerchants.MerchantNo
			left join
			Table_TraMerchantInfo
			on
				Coalesce(FinalyData.MerchantNo,Table_OraMerchants.MerchantNo) = Table_TraMerchantInfo.MerchantNo	

drop table #ORAData;
drop table #CompareORAData;
end
else if(@BizType = N'全部')
begin
	with AllData as
		(
			select
				FactDailyTrans.MerchantNo,
				SUM(SucceedTransAmount) TransAmt,
				SUM(SucceedTransCount) TransCnt
			from
				FactDailyTrans
			where 
				DailyTransDate >= @CurrStartDate
				and
				DailyTransDate < @CurrEndDate
				and
				GateNo not in (select GateNo from Table_GateCategory where GateCategory1 in ('EPOS','代扣'))
				and
				GateNo not in ('5901','5902')
				and
				FactDailyTrans.MerchantNo <> '808080510003188'
				and
				FactDailyTrans.MerchantNo <> '808080290000007'
				and
				FactDailyTrans.MerchantNo not in (select MerchantNo from dbo.Table_InstuMerInfo where InstuNo = '000020100816001')
			group by
				FactDailyTrans.MerchantNo
			union all
			select
				FactDailyTrans.MerchantNo,
				SUM(SucceedTransAmount) TransAmt,
				SUM(SucceedTransCount) TransCnt
			from
				FactDailyTrans
			where 
				DailyTransDate >= @CurrStartDate
				and
				DailyTransDate < @CurrEndDate
				and
				GateNo in (select GateNo from Table_GateCategory where GateCategory1 = 'EPOS')
				and
				FactDailyTrans.MerchantNo in (select MerchantNo from Table_EposTakeoffMerchant)
			group by
				FactDailyTrans.MerchantNo
		)
			select
				AllData.MerchantNo,
				SUM(AllData.TransAmt) TransAmt,
				SUM(AllData.TransCnt) TransCnt
			into
				#B2C_B2B_DK
			from
				AllData
			group by
				AllData.MerchantNo;


	with CuryRate as  
		(  
			select  
				CuryCode,  
				AVG(CuryRate) AVGCuryRate   
			from  
				Table_CuryFullRate  
			where  
				CuryDate >= @CurrStartDate
				and  
				CuryDate < @CurrEndDate
			group by  
				CuryCode
		)
	UPDATE
		#B2C_B2B_DK
	SET
		#B2C_B2B_DK.TransAmt = ISNULL(CuryRate.AVGCuryRate,1.0) * #B2C_B2B_DK.TransAmt
	FROM
		#B2C_B2B_DK
		inner join
		Table_MerInfoExt
		on
			#B2C_B2B_DK.MerchantNo = Table_MerInfoExt.MerchantNo
		inner join
		CuryRate
		on
			Table_MerInfoExt.CuryCode = CuryRate.CuryCode;


--1.2 Get CompareB2C Data
	with AllData as
		(
			select
				FactDailyTrans.MerchantNo,
				SUM(SucceedTransAmount) TransAmt,
				SUM(SucceedTransCount) TransCnt
			from
				FactDailyTrans
			where 
				DailyTransDate >= @PrevStartDate
				and
				DailyTransDate < @PrevEndDate
				and
				GateNo not in (select GateNo from Table_GateCategory where GateCategory1 in ('EPOS','代扣'))
				and
				GateNo not in ('5901','5902')
				and
				FactDailyTrans.MerchantNo <> '808080510003188'
				and
				FactDailyTrans.MerchantNo <> '808080290000007'
				and
				FactDailyTrans.MerchantNo not in (select MerchantNo from dbo.Table_InstuMerInfo where InstuNo = '000020100816001')
			group by
				FactDailyTrans.MerchantNo
			union all
			select
				FactDailyTrans.MerchantNo,
				SUM(SucceedTransAmount) TransAmt,
				SUM(SucceedTransCount) TransCnt
			from
				FactDailyTrans
			where 
				DailyTransDate >= @PrevStartDate
				and
				DailyTransDate < @PrevEndDate
				and
				GateNo in (select GateNo from Table_GateCategory where GateCategory1 = 'EPOS')
				and
				FactDailyTrans.MerchantNo in (select MerchantNo from Table_EposTakeoffMerchant)
			group by
				FactDailyTrans.MerchantNo
		)
			select
				AllData.MerchantNo,
				SUM(AllData.TransAmt) TransAmt,
				SUM(AllData.TransCnt) TransCnt
			into
				#CompareB2C_B2B_DK
			from
				AllData
			group by
				AllData.MerchantNo;

	with CuryRate as  
		(  
			select  
				CuryCode,  
				AVG(CuryRate) AVGCuryRate   
			from  
				Table_CuryFullRate  
			where  
				CuryDate >= @PrevStartDate
				and  
				CuryDate < @PrevEndDate
			group by  
				CuryCode
		)
	UPDATE
		#CompareB2C_B2B_DK
	SET
		#CompareB2C_B2B_DK.TransAmt = ISNULL(CuryRate.AVGCuryRate,1.0) * #CompareB2C_B2B_DK.TransAmt
	FROM
		#CompareB2C_B2B_DK
		inner join
		Table_MerInfoExt
		on
			#CompareB2C_B2B_DK.MerchantNo = Table_MerInfoExt.MerchantNo
		inner join
		CuryRate
		on
			Table_MerInfoExt.CuryCode = CuryRate.CuryCode;

	with FinalyData as
		(
			select
				coalesce(#B2C_B2B_DK.MerchantNo,#CompareB2C_B2B_DK.MerchantNo) as MerchantNo,
				ISNULL(#B2C_B2B_DK.TransAmt,0) as TransAmt,
				ISNULL(#B2C_B2B_DK.TransCnt,0) as TransCnt,
				ISNULL(#CompareB2C_B2B_DK.TransCnt,0) as CompareTransCnt,
				ISNULL(#CompareB2C_B2B_DK.TransAmt,0) as CompareTransAmt,
				(ISNULL(#B2C_B2B_DK.TransAmt,0)) - (ISNULL(#CompareB2C_B2B_DK.TransAmt,0)) as UpDataORDown
			from
				#B2C_B2B_DK
				full join
				#CompareB2C_B2B_DK
				on
					#B2C_B2B_DK.MerchantNo = #CompareB2C_B2B_DK.MerchantNo
		)
			select
				FinalyData.MerchantNo,
				Table_MerInfo.MerchantName,
				FinalyData.TransAmt/100.0 TransAmt,
				FinalyData.TransCnt,
				FinalyData.CompareTransCnt,
				FinalyData.CompareTransAmt/100.0 CompareTransAmt,
				FinalyData.UpDataORDown/100.0 UpDataORDown
			into
				#AllTypeB2C_B2B
			from
				FinalyData
				left join
				Table_MerInfo
				on
					FinalyData.MerchantNo = Table_MerInfo.MerchantNo;

--代收
	with AllDaiShouData as
		(
			select
				FactDailyTrans.MerchantNo,
				SUM(SucceedTransAmount) TransAmt,
				SUM(SucceedTransCount) TransCnt
			from
				FactDailyTrans
			where 
				DailyTransDate >= @CurrStartDate
				and
				DailyTransDate < @CurrEndDate
				and
				GateNo in (select GateNo from Table_GateCategory where GateCategory1 in ('代扣'))
			group by
				FactDailyTrans.MerchantNo
			union all
			select
				MerchantNo,
				SUM(CalFeeAmt) TransAmt,
				SUM(CalFeeCnt) TransCnt
			from
				Table_TraScreenSum
			where
				TransType in ('100001','100004')
				and
				CPDate >= @CurrStartDate
				and
				CPDate < @CurrEndDate
			group by
				MerchantNo
		)
			select
				MerchantNo,
				SUM(TransAmt) TransAmt,
				SUM(TransCnt) TransCnt
			into
				#AllTypeDaiShouData
			from
				AllDaiShouData
			group by
				MerchantNo;

	with CuryRate as  
		(  
			select  
				CuryCode,  
				AVG(CuryRate) AVGCuryRate   
			from  
				Table_CuryFullRate  
			where  
				CuryDate >= @CurrStartDate 
				and  
				CuryDate <  @CurrEndDate
			group by  
				CuryCode
		)
	UPDATE
		#AllTypeDaiShouData
	SET
		#AllTypeDaiShouData.TransAmt = ISNULL(CuryRate.AVGCuryRate,1.0) * #AllTypeDaiShouData.TransAmt
	FROM
		#AllTypeDaiShouData
		inner join
		Table_MerInfoExt
		on
			#AllTypeDaiShouData.MerchantNo = Table_MerInfoExt.MerchantNo
		inner join
		CuryRate
		on
			Table_MerInfoExt.CuryCode = CuryRate.CuryCode;

--Get Compare Data
	with AllDaiShouData as
		(
			select
				FactDailyTrans.MerchantNo,
				SUM(SucceedTransAmount) TransAmt,
				SUM(SucceedTransCount) TransCnt
			from
				FactDailyTrans
			where 
				DailyTransDate >= @PrevStartDate
				and
				DailyTransDate < @PrevEndDate
				and
				GateNo in (select GateNo from Table_GateCategory where GateCategory1 in ('代扣'))
			group by
				FactDailyTrans.MerchantNo
			union all
			select
				MerchantNo,
				SUM(CalFeeAmt) TransAmt,
				SUM(CalFeeCnt) TransCnt
			from
				Table_TraScreenSum
			where
				TransType in ('100001','100004')
				and
				CPDate >= @PrevStartDate
				and
				CPDate < @PrevEndDate
			group by
				MerchantNo
		)
			select
				MerchantNo,
				SUM(TransAmt) TransAmt,
				SUM(TransCnt) TransCnt
			into
				#CompareAllTypeDaiShouData
			from
				AllDaiShouData
			group by
				MerchantNo;

	with CuryRate as  
		(  
			select  
				CuryCode,  
				AVG(CuryRate) AVGCuryRate   
			from  
				Table_CuryFullRate  
			where  
				CuryDate >= @PrevStartDate 
				and  
				CuryDate <  @PrevEndDate
			group by  
				CuryCode
		)
	UPDATE
		#CompareAllTypeDaiShouData
	SET
		#CompareAllTypeDaiShouData.TransAmt = ISNULL(CuryRate.AVGCuryRate,1.0) * #CompareAllTypeDaiShouData.TransAmt
	FROM
		#CompareAllTypeDaiShouData
		inner join
		Table_MerInfoExt
		on
			#CompareAllTypeDaiShouData.MerchantNo = Table_MerInfoExt.MerchantNo
		inner join
		CuryRate
		on
			Table_MerInfoExt.CuryCode = CuryRate.CuryCode;

	with FinalyData as
		(
			select
				coalesce(#AllTypeDaiShouData.MerchantNo,#CompareAllTypeDaiShouData.MerchantNo) as MerchantNo,
				ISNULL(#AllTypeDaiShouData.TransAmt,0) as TransAmt,
				ISNULL(#AllTypeDaiShouData.TransCnt,0) as TransCnt,
				ISNULL(#CompareAllTypeDaiShouData.TransCnt,0) as CompareTransCnt,
				ISNULL(#CompareAllTypeDaiShouData.TransAmt,0) as CompareTransAmt,
				(ISNULL(#AllTypeDaiShouData.TransAmt,0)) - (ISNULL(#CompareAllTypeDaiShouData.TransAmt,0)) as UpDataORDown
			from
				#AllTypeDaiShouData
				full join
				#CompareAllTypeDaiShouData
				on
					#AllTypeDaiShouData.MerchantNo = #CompareAllTypeDaiShouData.MerchantNo
		)
			select
				FinalyData.MerchantNo,
				Table_MerInfo.MerchantName,
				FinalyData.TransAmt/100.0 TransAmt,
				FinalyData.TransCnt,
				FinalyData.CompareTransCnt,
				FinalyData.CompareTransAmt/100.0 CompareTransAmt,
				FinalyData.UpDataORDown/100.0 UpDataORDown
			into
				#AllType_DaiShou
			from
				FinalyData
				left join
				Table_MerInfo
				on
					FinalyData.MerchantNo = Table_MerInfo.MerchantNo;

--代付
	with AllORAData as
		(
			select
				MerchantNo,
				SUM(TransAmount) TransAmt,
				SUM(TransCount) TransCnt
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
				SUM(CalFeeAmt) TransAmt,
				SUM(CalFeeCnt) TransCnt
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
		)
			select
				MerchantNo,
				SUM(TransAmt) TransAmt,
				SUM(TransCnt) TransCnt
			into
				#AllTypeORAData
			from
				AllORAData
			group by
				MerchantNo;


	--Get Compare Data
	with AllORAData as
		(
			select
				MerchantNo,
				SUM(TransAmount) TransAmt,
				SUM(TransCount) TransCnt
			from
				Table_OraTransSum
			where 
				CPDate >= @PrevStartDate
				and
				CPDate <  @PrevEndDate
			group by
				MerchantNo
			union all
			select
				MerchantNo,
				SUM(CalFeeAmt) TransAmt,
				SUM(CalFeeCnt) TransCnt
			from
				Table_TraScreenSum
			where
				CPDate >= @PrevStartDate
				and
				CPDate <  @PrevEndDate
				and
				TransType in ('100002','100005')
			group by 
				MerchantNo
		)
			select
				MerchantNo,
				SUM(TransAmt) TransAmt,
				SUM(TransCnt) TransCnt
			into
				#CompareAllTypeORAData
			from
				AllORAData
			group by
				MerchantNo;

--TempResult
	with FinalyData as
	(
		select
			coalesce(#AllTypeORAData.MerchantNo,#CompareAllTypeORAData.MerchantNo) as MerchantNo,
			ISNULL(#AllTypeORAData.TransAmt,0) as TransAmt,
			ISNULL(#AllTypeORAData.TransCnt,0) as TransCnt,
			ISNULL(#CompareAllTypeORAData.TransCnt,0) as CompareTransCnt,
			ISNULL(#CompareAllTypeORAData.TransAmt,0) as CompareTransAmt,
			(ISNULL(#AllTypeORAData.TransAmt,0)) - (ISNULL(#CompareAllTypeORAData.TransAmt,0)) as UpDataORDown
		from
			#AllTypeORAData
			full join
			#CompareAllTypeORAData
			on
				#AllTypeORAData.MerchantNo = #CompareAllTypeORAData.MerchantNo
	)
		select
			FinalyData.MerchantNo,
			coalesce(Table_OraMerchants.MerchantName,Table_TraMerchantInfo.MerchantName) MerchantName,
			FinalyData.TransAmt/100.0 TransAmt,
			FinalyData.TransCnt,
			FinalyData.CompareTransCnt,
			FinalyData.CompareTransAmt/100.0 CompareTransAmt,
			FinalyData.UpDataORDown/100.0 UpDataORDown
		into
			#AllType_ORAData
		from
			FinalyData
			left join
			Table_OraMerchants
			on
				FinalyData.MerchantNo = Table_OraMerchants.MerchantNo
			left join
			Table_TraMerchantInfo
			on
				Coalesce(FinalyData.MerchantNo,Table_OraMerchants.MerchantNo) = Table_TraMerchantInfo.MerchantNo;

	insert into #TempMerTrans
		select * from #AllTypeB2C_B2B
		union all
		select * from #AllType_DaiShou
		union all
		select * from #AllType_ORAData


	drop table #AllTypeB2C_B2B;
	drop table #AllType_DaiShou;
	drop table #AllType_ORAData;
end


--Result
if(@UpOrDown = '上涨')
begin
	select
		TOP(@TopNum)
		*
	from
		#TempMerTrans
	order by
		UpDataORDown DESC
end
else if(@UpOrDown = '下降')
begin
	select
		TOP(@TopNum) 
		*
	from
		#TempMerTrans
	order by
		UpDataORDown 
end;

drop table #TempMerTrans;

end