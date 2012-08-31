--[Create] At 20120724 By DJH:  Proc_QueryTempGateNoAmt
--Input: @StartDate,@EndDate,@TimeType,@CurrencyType
--Output: GrpName,ItemNo,MerchantName,Amt,Cnt,Fee,Cost
If OBJECT_ID(N'Proc_QueryTempGateNoAmt',N'p')is not null
begin
	drop procedure Proc_QueryTempGateNoAmt;
end
go

create procedure Proc_QueryTempGateNoAmt
	@StartDate datetime = '2012-01-01',
	@EndDate datetime = '2012-01-30',
	@TimeType char(10) = 'FeeDate',
	@CurrencyType char(10) = 'Orig'
as
begin
--1. Check input
	if(@StartDate is null or @EndDate is null or @TimeType is null or @CurrencyType is null)
	begin
		raiserror(N'Input params cannot be empty in Proc_QueryTempGateNoAmt',16,1)
	end


--2. Prepare @StartDate and @EndDate
	declare @CurrStartDate datetime;
	declare @CurrEndDate datetime;
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(DAY,1,@EndDate);


--3. Put ItemType is Merchant records into #TempMers
	select distinct
		ItemNo
	into
		#TempGateNo
	from
		Table_GrpItemRelation
	where
		ItemType = 'Gate';
		
	select distinct	
		GrpName,
		ItemNo	
	into		
		#FinalGates	
	from		
		Table_GrpItemRelation	
	where		
		ItemType = 'Gate';


--4. @TimeType is TransDate
	if(@TimeType = 'TransDate')
	begin
		--4.1 Put Ora Amt data into #OraTransData
		select
			ORA.BankSettingID BankSettingID,
			ORA.MerchantNo MerchantNo,
			SUM(ORA.TransAmount) TransAmt,
			SUM(ORA.TransCount) TransCnt
		into
			#OraTransData
		from
			Table_OraTransSum ORA
			inner join
			#TempGateNo GateNo
			on
				ORA.BankSettingID = GateNo.ItemNo
		where
			ORA.CPDate >= @CurrStartDate
			and
			ORA.CPDate < @CurrEndDate
		group by
			ORA.BankSettingID,
			ORA.MerchantNo;


--4.1 Put payment Amt Data Into 
		select
			FactDaily.GateNo GateNo,
			FactDaily.MerchantNo MerchantNo,
			SUM(SucceedTransAmount) TransAmt,
			SUM(SucceedTransCount) TransCnt
		into
			#PayTransData
		from
			FactDailyTrans FactDaily
			inner join
			#TempGateNo GateNo
			on
				FactDaily.GateNo = GateNo.ItemNo
		where
			FactDaily.DailyTransDate >= @CurrStartDate
			and
			FactDaily.DailyTransDate < @CurrEndDate
		group by
			FactDaily.GateNo,
			FactDaily.MerchantNo;
	
	
--4.2 Convert to RMB
		If(@CurrencyType = N'RMB')
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


--4.3 Query Final Result
		With AllTransAmt as 
		(
			select
				Ora.BankSettingID ItemNo,
				Ora.MerchantNo MerchantNo,
				(select MerchantName from Table_OraMerchants where MerchantNo = Ora.MerchantNo) as MerchantName,
				TransAmt Amt,
				TransCnt Cnt
			from
				#OraTransData Ora
			union all
			select
				Pay.GateNo ItemNo,
				Pay.MerchantNo MerchantNo,
				(select MerchantName from Table_MerInfo where MerchantNo = Pay.MerchantNo) MerchantName,
				TransAmt Amt,
				TransCnt Cnt
			from
				#PayTransData Pay
		)
		select
			Gates.GrpName,
			ISNULL(Gates.ItemNo,N'') as ItemNo,
			ISNULL(AllTransAmt.MerchantNo,N'') as MerchantNo,
			ISNULL(AllTransAmt.MerchantName,N'') as MerchantName,
			ISNULL(AllTransAmt.Amt, 0)/100.0 as Amt,
			ISNULL(AllTransAmt.Cnt, 0) as Cnt,
			0 as Fee,
			0 as Cost
		from
			#FinalGates Gates
			left join
			AllTransAmt
			on
				Gates.ItemNo = AllTransAmt.ItemNo;


		drop table #OraTransData;
		drop table #PayTransData;
	end

--5. @TimeType is FeeDate		
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


--5.1 Put Proc_CalOraCost data into #CalOraCost
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
	
	
--5.2 Put FeeORA Amt data into #OraData
		select
			OraTransSum.BankSettingID,
			OraTransSum.MerchantNo MerchantNo,
			SUM(OraTransSum.FeeAmount) FeeAmt,
			SUM(OraTransSum.TransCount) TransCnt
		into
			#OraFeeData
		from
			Table_OraTransSum OraTransSum
			inner join
			#TempGateNo GateNo
			on
				OraTransSum.BankSettingID = GateNo.ItemNo
		where
			OraTransSum.CPDate >= @CurrStartDate
			and
			OraTransSum.CPDate < @CurrEndDate
		group by
			OraTransSum.BankSettingID,
			OraTransSum.MerchantNo;
			
		update
			OraFeeData
		set
			OraFeeData.FeeAmt = OraFeeData.TransCnt * AdditionalRule.FeeValue
		from
			#OraFeeData OraFeeData
			inner join
			Table_OraAdditionalFeeRule AdditionalRule
			on
				OraFeeData.MerchantNo = AdditionalRule.MerchantNo;


		With OraCostData as
		(	
			select
				CalOraCost.BankSettingID,
				CalOraCost.MerchantNo MerchantNo,
				SUM(CalOraCost.TransAmt) TransAmt,
				SUM(CalOraCost.TransCnt) TransCnt,
				SUM(CalOraCost.CostAmt) CostAmt
			from
				#CalOraCost CalOraCost
				inner join
				#TempGateNo GateNo
				on
					CalOraCost.BankSettingID = GateNo.ItemNo
			group by
				CalOraCost.BankSettingID,
				CalOraCost.MerchantNo
		),
		OraFeeData as
		(	
			select
				OraFee.BankSettingID,
				OraFee.MerchantNo MerchantNo,
				SUM(OraFee.FeeAmt) FeeAmt
			from
				#OraFeeData OraFee
			group by
				OraFee.BankSettingID,
				OraFee.MerchantNo
		)
		select
			OraCostData.BankSettingID,
			OraCostData.MerchantNo,
			OraCostData.TransAmt,
			OraCostData.TransCnt,
			OraFeeData.FeeAmt,
			OraCostData.CostAmt
		into
			#OraBillingData
		from
			OraCostData
			inner join
			OraFeeData
			on
				OraCostData.BankSettingID = OraFeeData.BankSettingID
				and
				OraCostData.MerchantNo = OraFeeData.MerchantNo;
	
	
----5.3 Convert to FeeValue
	
	
--5.4 Put Ora data into #OraBillingData
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
	
--5.5 @CurrencyType Conversion
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
		
--5.6 Put PaymentCost Amt data into #PayBillingData
		select
			CalPaymentCost.GateNo,
			CalPaymentCost.MerchantNo MerchantNo,
			SUM(CalPaymentCost.TransAmt) TransAmt,
			SUM(CalPaymentCost.TransCnt) TransCnt,
			SUM(CalPaymentCost.FeeAmt) FeeAmt,
			SUM(CalPaymentCost.CostAmt) CostAmt
		into
			#PayBillingData
		from
			#CalPaymentCost CalPaymentCost
			inner join
			#TempGateNo GateNo
			on
				CalPaymentCost.GateNo = GateNo.ItemNo
		group by
			CalPaymentCost.GateNo,
			CalPaymentCost.MerchantNo;
		
		
--5.7 Query Final Result
		With AllBillingAmt as
		(
			select
				Ora.BankSettingID ItemNo,
				Ora.MerchantNo MerchantNo,
				(select MerchantName from Table_OraMerchants where MerchantNo = Ora.MerchantNo ) as MerchantName,
				Ora.TransAmt Amt,
				Ora.TransCnt Cnt,
				Ora.FeeAmt Fee,
				Ora.CostAmt Cost
			from
				#OraBillingData Ora
			union all
			select
				Pay.GateNo ItemNo,
				Pay.MerchantNo MerchantNo,
				(select MerchantName from Table_MerInfo where MerchantNo = Pay.MerchantNo) as MerchantName,
				Pay.TransAmt Amt,
				Pay.TransCnt Cnt,
				Pay.FeeAmt Fee,
				Pay.CostAmt Cost
			from
				#PayBillingData Pay
		)
		select
			GateNo.GrpName,
			GateNo.ItemNo,
			AllBillingAmt.MerchantNo,
			AllBillingAmt.MerchantName,
			ISNULL(AllBillingAmt.Amt, 0)/100.0 as Amt,
			ISNULL(AllBillingAmt.Cnt, 0) as Cnt,
			ISNULL(AllBillingAmt.Fee, 0)/100.0 as Fee,
			ISNULL(AllBillingAmt.Cost, 0)/100.0 as Cost
		from
			#FinalGates GateNo
			left join
			AllBillingAmt
			on
				GateNo.ItemNo = AllBillingAmt.ItemNo
		
		
--5.8 Drop Table 
		drop table #CalOraCost;
		drop table #OraFeeData;
		drop table #OraBillingData;
		drop table #CalPaymentCost;
		drop table #PayBillingData;		

	end

	drop table #TempGateNo;
	drop table #FinalGates;
end






















	