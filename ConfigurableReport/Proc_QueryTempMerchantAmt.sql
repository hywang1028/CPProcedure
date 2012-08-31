--[Create] At 20120724 By WuChen:  Proc_QueryTempGateNoAmt
--Input: @StartDate,@EndDate,@TimeType,@CurrencyType
--Output: GrpName,ItemNo,BankSettingID,MerchantName,Amt,Cnt,Fee,Cost

if OBJECT_ID(N'Proc_QueryTempMerchantAmt', N'P') is not null
begin
	drop procedure Proc_QueryTempMerchantAmt;
end
go

create procedure Proc_QueryTempMerchantAmt
	@StartDate datetime = '2012-01-01',
	@EndDate datetime = '2012-01-30',
	@TimeType char(10) = 'FeeDate',
	@CurrencyType char(10) = 'Orig'
as
begin

	--1. Check input
	if (@StartDate is null or @EndDate is null or @TimeType is null or @CurrencyType is null)
	begin 
		raiserror(N'Input params cannot be empty in Proc_QueryTempMerchantAmt',16,1)
	end


	--2. Prepare @StartDate and @EndDate
	declare @CurrStartDate datetime;
	declare @CurrEndDate datetime;
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(DAY,1,@EndDate);

	-- Put ItemType is Merchant records into #TempMers
	select distinct
		ItemNo
	into
		#TempMers
	from
		Table_GrpItemRelation
	where
		ItemType = 'Merchant';
		
	select distinct
		GrpName,
		ItemNo,
		coalesce(Table_MerInfo.MerchantName,Table_OraMerchants.MerchantName) MerchantName
	into
		#FinalMers
	from
		Table_GrpItemRelation
		left join
		Table_MerInfo
		on
			Table_GrpItemRelation.ItemNo = Table_MerInfo.MerchantNo
		left join
		Table_OraMerchants
		on
			Table_GrpItemRelation.ItemNo = Table_OraMerchants.MerchantNo
	where
		ItemType = 'Merchant';		
		
	select
		N'' as GateNo,
		WU.MerchantNo,
		SUM(WU.DestTransAmount) TransAmt,
		COUNT(MerchantNo) TransCnt
	into
		#WUData
	from
		Table_WUTransLog WU
		inner join
		#TempMers Mers
		on
			WU.MerchantNo = Mers.ItemNo
	where
		CPDate >= @CurrStartDate
		and
		CPDate < @CurrEndDate
	group by
		MerchantNo;

		
	--3. @TimeType is TransDate
	if(@TimeType = 'TransDate')
	begin
		--3.1 Put Ora and WUTrans Amt data into #OraWUTransData
		select
			ORA.MerchantNo MerchantNo,
			ORA.BankSettingID BankSettingID,
			SUM(ORA.TransAmount) TransAmt,
			SUM(ORA.TransCount) TransCnt
		into
			#OraWUTransData
		from
			Table_OraTransSum ORA
			inner join
			#TempMers Mers
			on
				ORA.MerchantNo = Mers.ItemNo
		where
			ORA.CPDate >= @CurrStartDate
			and
			ORA.CPDate < @CurrEndDate
		group by
			MerchantNo,
			BankSettingID
		union all
		select
			MerchantNo,
			N'' as BankSettingID,
			TransAmt,
			TransCnt
		from
			#WUData;

		--3.2 Put Payment Amt data into #PayTransData
		select
			FactDaily.MerchantNo,
			FactDaily.GateNo,
			SUM(FactDaily.SucceedTransAmount) TransAmt,
			SUM(FactDaily.SucceedTransCount) TransCnt
		into
			#PayTransData
		from
			FactDailyTrans FactDaily
			inner join
			#TempMers Mers
			on
				FactDaily.MerchantNo = Mers.ItemNo
		where
			FactDaily.DailyTransDate >= @CurrStartDate
			and
			FactDaily.DailyTransDate < @CurrEndDate
		group by
			MerchantNo,
			GateNo;
		
		--3.3 convert to RMB
		if(@CurrencyType = 'RMB')
		begin
			select
				CuryCode,
				AVG(CuryRate) AvgRate
			into
				#CuryRate
			from
				Table_CuryFullRate
			where
				CuryDate >= @CurrStartDate
				and
				CuryDate < @CurrEndDate
			group by
				CuryCode;
		
			update
				Pay
			set
				Pay.TransAmt = Pay.TransAmt * CuryRate.AvgRate
			from
				#PayTransData Pay
				inner join
				Table_MerInfoExt MerInfoExt
				on
					Pay.MerchantNo = MerInfoExt.MerchantNo
				inner join
				#CuryRate CuryRate
				on
					MerInfoExt.CuryCode = CuryRate.CuryCode;
					
			drop table #CuryRate;
		end;
		
		--3.4 Query Final Result
		With AllTransAmt as 
		(
			select
				OraWU.MerchantNo,
				OraWU.BankSettingID,
				TransAmt Amt,
				TransCnt Cnt
			from
				#OraWUTransData OraWU
			union all
			select
				Pay.MerchantNo,
				Pay.GateNo,
				TransAmt Amt,
				TransCnt Cnt
			from
				#PayTransData Pay
		)
		select
			Mers.GrpName,
			Mers.ItemNo as ItemNo,
			ISNULL(AllTransAmt.BankSettingID,N'') BankSettingID,
			ISNULL(Mers.MerchantName, N'') as MerchantName,
			ISNULL(AllTransAmt.Amt, 0)/100.0 as Amt,
			ISNULL(AllTransAmt.Cnt, 0) as Cnt,
			0 as Fee,
			0 as Cost
		from
			#FinalMers Mers
			left join
			AllTransAmt
			on
				Mers.ItemNo = AllTransAmt.MerchantNo;
				
		drop table #OraWUTransData;
		drop table #PayTransData;
	end

	--4. @TimeType is FeeDate
	else if(@TimeType = 'FeeDate')				
	begin					
		create table #CalOraCost
		(
			BankSettingID char(8),
			MerchantNo char(20),
			CPDate datetime,
			TransCnt bigint,
			TransAmt bigint,
			CostAmt bigint
		);
		
	--4.1 Put Proc_CalOraCost data into #CalOraCost
		insert into #CalOraCost
		(
			BankSettingID,
			MerchantNo,
			CPDate,
			TransCnt,
			TransAmt,
			CostAmt 
		)
		exec Proc_CalOraCost 
			@CurrStartDate, 
			@CurrEndDate, 
			null;
			
	--4.2 Put FeeORA Amt data into #OraData
		With OraCostData as
		(	
			select
				CalOraCost.MerchantNo,
				CalOraCost.BankSettingID,
				SUM(CalOraCost.TransAmt) TransAmt,
				SUM(CalOraCost.TransCnt) TransCnt,
				SUM(CalOraCost.CostAmt) CostAmt
			from
				#CalOraCost CalOraCost
				inner join
				#TempMers Mers
				on
					CalOraCost.MerchantNo = Mers.ItemNo
			group by
				CalOraCost.MerchantNo,
				CalOraCost.BankSettingID
		),
		OraFeeData as
		(	
			select
				OraTransSum.MerchantNo,
				OraTransSum.BankSettingID,
				SUM(OraTransSum.FeeAmount) FeeAmt
			from
				Table_OraTransSum OraTransSum
				inner join
				#TempMers Mers
				on
					OraTransSum.MerchantNo = Mers.ItemNo
			where
				CPDate >= @CurrStartDate
				and
				CPDate < @CurrEndDate
			group by
				OraTransSum.MerchantNo,
				OraTransSum.BankSettingID
		)
		select
			OraCostData.MerchantNo,
			OraCostData.BankSettingID,
			OraCostData.TransAmt,
			OraCostData.TransCnt,
			OraFeeData.FeeAmt,
			OraCostData.CostAmt
		into
			#OraData
		from
			OraCostData
			inner join
			OraFeeData
			on
				OraCostData.MerchantNo = OraFeeData.MerchantNo
				and
				OraCostData.BankSettingID = OraFeeData.BankSettingID
		order by
			OraCostData.BankSettingID
				
	----4.3 Convert to FeeValue
		update
			OraData
		set
			OraData.FeeAmt = OraData.TransCnt * AdditionalRule.FeeValue
		from
			#OraData OraData
			inner join
			Table_OraAdditionalFeeRule AdditionalRule
			on
				OraData.MerchantNo = AdditionalRule.MerchantNo;
				
	----4.4 Put OraWU data into #OraWUBillingData
		select
			MerchantNo,
			BankSettingID,
			TransAmt,
			TransCnt,
			FeeAmt,
			CostAmt
		into
			#OraWUBillingData
		from
			#OraData
		union all
		select
			MerchantNo,
			GateNo,
			TransAmt,
			TransCnt,
			0 FeeAmt,
			0 CostAmt
		from
			#WUData;
			
		create table #CalPaymentCost
		(
			GateNo char(4),
			MerchantNo char(20),
			FeeEndDate datetime,
			TransCnt bigint,
			TransAmt decimal(16,2),
			CostAmt decimal(18,4),
			FeeAmt decimal(16,2),
			InstuFeeAmt decimal(16,2)
		);
		
	----4.5 @CurrencyType Conversion
		if (@CurrencyType = 'Orig')
		begin
			insert into #CalPaymentCost
			(
				GateNo,
				MerchantNo,
				FeeEndDate,
				TransCnt,
				TransAmt,
				CostAmt,
				FeeAmt,
				InstuFeeAmt
			)
			exec Proc_CalPaymentCost
				@CurrStartDate,
				@CurrEndDate,
				null,
				null;
		end
		else if (@CurrencyType = 'RMB')
		begin
			insert into #CalPaymentCost
			(
				GateNo,
				MerchantNo,
				FeeEndDate,
				TransCnt,
				TransAmt,
				CostAmt,
				FeeAmt,
				InstuFeeAmt
			)
			exec Proc_CalPaymentCost
				@CurrStartDate,
				@CurrEndDate,
				null,
				'on';
		end
		
	----4.6 Put PaymentCost Amt data into #PayBillingData
		select
			CalPaymentCost.MerchantNo,
			CalPaymentCost.GateNo,
			SUM(CalPaymentCost.TransAmt) TransAmt,
			SUM(CalPaymentCost.TransCnt) TransCnt,
			SUM(CalPaymentCost.FeeAmt) FeeAmt,
			SUM(CalPaymentCost.CostAmt) CostAmt
		into
			#PayBillingData
		from
			#CalPaymentCost CalPaymentCost
			inner join
			#TempMers Mers
			on
				CalPaymentCost.MerchantNo = Mers.ItemNo
		group by
			CalPaymentCost.MerchantNo,
			CalPaymentCost.GateNo;
			
	--4.7 Query Final Result
		With AllBillingAmt as
		(
			select
				OraWU.MerchantNo,
				OraWU.BankSettingID BankSettingID,
				OraWU.TransAmt Amt,
				OraWU.TransCnt Cnt,
				OraWU.FeeAmt Fee,
				OraWU.CostAmt Cost
			from
				#OraWUBillingData OraWU
			union all
			select
				Pay.MerchantNo,
				Pay.GateNo,
				Pay.TransAmt Amt,
				Pay.TransCnt Cnt,
				Pay.FeeAmt Fee,
				Pay.CostAmt Cost
			from
				#PayBillingData Pay
		)
		select
			Mers.GrpName,
			Mers.ItemNo as ItemNo,
			AllBillingAmt.BankSettingID,
			ISNULL(Mers.MerchantName, N'') as MerchantName,
			ISNULL(AllBillingAmt.Amt, 0)/100.0 as Amt,
			ISNULL(AllBillingAmt.Cnt, 0) as Cnt,
			ISNULL(AllBillingAmt.Fee, 0)/100.0 as Fee,
			ISNULL(AllBillingAmt.Cost, 0)/100.0 as Cost
		from
			#FinalMers Mers
			left join
			AllBillingAmt
			on
				Mers.ItemNo = AllBillingAmt.MerchantNo;
				
	--4.8 Drop tmp table(Branch)
		drop table #CalOraCost;
		drop table #OraData;
		drop table #OraWUBillingData;
		drop table #CalPaymentCost;
		drop table #PayBillingData;
	end
	--5. Drop tmp table 
	drop table #TempMers;
	drop table #FinalMers;
	drop table #WUData;
end

