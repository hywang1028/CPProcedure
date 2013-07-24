--[Modified] at 2012-07-13 by 王红燕  Description:Add Financial Dept Configuration Data
--[Modified] at 2012-12-13 by 王红燕  Description:Add Branch Office Fund Trans Data
--[Modified] at 2013-07-01 by 丁俊昊  Description:Add UPOP Data and TraScreenSum Data and 
if OBJECT_ID(N'Proc_QueryBranchOfficeSummarize',N'P') is not null
begin
	drop procedure Proc_QueryBranchOfficeSummarize;
end
go

create procedure Proc_QueryBranchOfficeSummarize
	@StartDate datetime = '2012-11-01',
	@EndDate datetime = '2012-11-12',
	@PeriodUnit nChar(3) = N'自定义'
as 
begin

--1. Check Input
if (@StartDate is null or ISNULL(@PeriodUnit,N'') = N'' or (@PeriodUnit = N'自定义' and @EndDate is null))
begin
	raiserror('Input parameters can`t be empty in Proc_QueryBranchOfficeSummarize!',16,1);
end


--2. Prepare StartDate and EndDate
declare @CurrStartDate datetime;
declare @CurrEndDate datetime;


if (@PeriodUnit = N'月')
begin
	set @CurrStartDate = LEFT(CONVERT(char,@StartDate,120),7) + '-01';
	set @CurrEndDate = DATEADD(month,1,@CurrStartDate);
end	
else if(@PeriodUnit = N'季度')
begin
	set @CurrStartDate = LEFT(CONVERT(char,@StartDate,120),7) + '-01';
	set @CurrEndDate = DATEADD(QUARTER,1,@CurrStartDate);
end
else if(@PeriodUnit = N'半年')
begin
	set @CurrStartDate = LEFT(CONVERT(char,@StartDate,120),7) + '-01';
	set @CurrEndDate = DATEADD(QUARTER,2,@CurrStartDate);
end
else if(@PeriodUnit = N'自定义')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(DAY,1,@EndDate);
end;


--3.Prepare All Data
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
		Trans.DailyTransLog_MerchantNo MerchantNo,
		Trans.DailyTransLog_GateNo GateNo,
		SUM(Trans.DailyTransLog_SucceedTransCount) as TransCnt,
		SUM(Trans.DailyTransLog_SucceedTransAmount) as TransAmt
	from
		Table_InvalidDailyTrans Trans
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
	ISNULL(Data.TransCnt,0)+ISNULL(Invalid.TransCnt,0) TransCnt,
	ISNULL(Data.TransAmt,0)+ISNULL(Invalid.TransAmt,0) TransAmt
into
	#PaymentData
from
	ValidPayData Data
	full outer join
	InvalidPayData Invalid
	on
		Data.MerchantNo = Invalid.MerchantNo
		and
		Data.GateNo = Invalid.GateNo
where
	coalesce(Data.MerchantNo,Invalid.MerchantNo)not in ('808080290000007');


--3.1. Prepare '商城（上报）' Data
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
	EmallTransSum.MerchantNo,
	EmallTransSum.TransCnt as EmallTransCnt,
	EmallTransSum.TransAmt as EmallTransAmt
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


--3.2 Prepare B2C(除UPOP)_Data
select 
	N'' as BranchOffice,
	MerchantNo,
	SUM(TransCnt) as TransCnt,
	SUM(TransAmt) as TransAmt
into
	#B2CNoUPOP
from
	#PaymentData Trans
where
	GateNo not in (select GateNo from Table_GateCategory where GateCategory1 in ('B2B','UPOP',N'代扣'))
group by
	MerchantNo
union all
select
	*
from
	#EmallTransData;


--4. Prepare UPOP_Data
select
	case when
		UPOP.MerchantNo = CPRelation.UpopMerNo
	then
		CPRelation.CpMerNo
	else
		UPOP.MerchantNo
	end
		as MerchantNo,
	SUM(PurCnt) TransCnt,
	SUM(PurAmt) TransAmt
into
	#UPOPData
from
	Table_UpopliqFeeLiqResult UPOP
	left join
	Table_CpUpopRelation CPRelation
	on
		UPOP.MerchantNo = CPRelation.UpopMerNo
where
	TransDate >= @CurrStartDate
	and
	TransDate < @CurrEndDate
group by
	UPOP.MerchantNo,
	CPRelation.CpMerNo,
	CPRelation.UpopMerNo
union all
select
	MerchantNo,
	SUM(TransCnt) TransCnt,
	SUM(TransAmt) TransAmt
from
	#PaymentData
where
	GateNo in (select GateNo from Table_GateCategory where GateCategory1 = 'UPOP')
group by
	MerchantNo;


--5. Prepare B2B_Data
select
	MerchantNo,
	SUM(TransCnt) as TransCnt,
	SUM(TransAmt) as TransAmt
into
	#B2BData
from
	#PaymentData
where
	GateNo in (select GateNo from Table_GateCategory where GateCategory1 in ('B2B'))
group by
	MerchantNo;


--6.Prepare '代收' Data
with FinalyDeductData as
(
select
	MerchantNo,
	SUM(TransCnt) TransCnt,
	SUM(TransAmt) TransAmt
from
	#PaymentData
where
	GateNo in (select GateNo from Table_GateCategory where GateCategory1 = N'代扣')
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
	CPDate < @CurrEndDate
	and
	TransType in ('100001','100004')
group by
	MerchantNo
)
select
	MerchantNo,
	SUM(TransCnt) TransCnt,
	SUM(TransAmt) TransAmt
into
	#DeductTransData
from
	FinalyDeductData
group by
	MerchantNo;


--7. Prepare ORA_Data and Tra_Data and UPOP_Data
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


--8. Prepare Fund_Data
select
	BranchOfficeNameRule.NormalBranchOfficeName BranchOffice,
	SUM(Branch.B2BPurchaseCnt+Branch.B2BRedemptoryCnt+Branch.B2CPurchaseCnt+Branch.B2CRedemptoryCnt) TransCnt,
	SUM(Branch.B2BPurchaseAmt+Branch.B2BRedemptoryAmt+Branch.B2CPurchaseAmt+Branch.B2CRedemptoryAmt) TransAmt
into
	#FundData
from
	Table_UMSBranchFundTrans Branch
	inner join
	Table_BranchOfficeNameRule BranchOfficeNameRule
	on
		Branch.BranchOfficeName = BranchOfficeNameRule.UnnormalBranchOfficeName
where
	TransDate >= @CurrStartDate
	and
	TransDate < @CurrEndDate
group by
	BranchOfficeNameRule.NormalBranchOfficeName;


select
	MerchantNo
into
	#NewlyOpenMer
from
	Table_MerOpenAccountInfo
where
	OpenAccountDate >= @CurrStartDate
	and
	OpenAccountDate < @CurrEndDate;


--9.Get MerchantNoWithBranchOffice 
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
			and
			ISNULL(BranchOffice.UmsSpec,N'') <> N''
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
			and
			ISNULL(BranchOffice.UmsSpec,N'') <> N''
)
select
	Coalesce(Sales.MerchantNo,Finance.MerchantNo) MerchantNo,
	Coalesce(Sales.BranchOffice,Finance.BranchOffice) BranchOffice
into
	#MerWithBranch
from
	SalesBranchOffice Sales
	full outer join
	FinanceBranchOffice Finance
	on
		RTRIM(Sales.MerchantNo) = RTRIM(Finance.MerchantNo);


--10. Get Respectively BranchOffice
select
	coalesce(MerWithBranch.BranchOffice,B2CNoUPOP.BranchOffice) BranchOffice,
	coalesce(MerWithBranch.MerchantNo,B2CNoUPOP.MerchantNo) MerchantNo,
	ISNULL(B2CNoUPOP.TransCnt,0) B2CNoUPOPTransCnt,
	ISNULL(UPOPData.TransCnt,0) UPOPTransCnt,
	ISNULL(B2BData.TransCnt,0) B2BTransCnt,
	ISNULL(Deduct.TransCnt,0) DeductTransCnt,
	ISNULL(ORA.TransCnt,0) ORATransCnt,
	ISNULL(B2CNoUPOP.TransAmt,0) B2CNoUPOPTransAmt,
	ISNULL(UPOPData.TransAmt,0) UPOPTransAmt,
	ISNULL(B2BData.TransAmt,0) B2BTransAmt,
	ISNULL(Deduct.TransAmt,0) DeductTransAmt,
	ISNULL(ORA.TransAmt,0) ORATransAmt
into
	#AllMerWithBranch
from
	#MerWithBranch MerWithBranch
	full join
	#B2CNoUPOP B2CNoUPOP
	on
		MerWithBranch.MerchantNo = B2CNoUPOP.MerchantNo
	left join
	#B2BData B2BData
	on
		MerWithBranch.MerchantNo = B2BData.MerchantNo
	left join
	#UPOPData UPOPData
	on
		MerWithBranch.MerchantNo = UPOPData.MerchantNo
	left join
	#DeductTransData Deduct
	on
		MerWithBranch.MerchantNo = Deduct.MerchantNo
	left join
	#ORAWUTransData ORA
	on
		MerWithBranch.MerchantNo = ORA.MerchantNo;


--12. Get Result
With TempResult as
(
	select
		AllMerWithBranch.BranchOffice,
		COUNT(NewlyOpenMer.MerchantNo) NewlyIncreMerCount,
		SUM(ISNULL(AllMerWithBranch.B2CNoUPOPTransCnt,0)) B2CNoUPOPTransCnt,
		SUM(ISNULL(AllMerWithBranch.UPOPTransCnt,0)) UPOPTransCnt,
		SUM(ISNULL(AllMerWithBranch.B2BTransCnt,0)) B2BTransCnt,
		SUM(ISNULL(AllMerWithBranch.DeductTransCnt,0)) DeductTransCnt,
		SUM(ISNULL(AllMerWithBranch.ORATransCnt,0)) ORATransCnt,
		SUM(ISNULL(AllMerWithBranch.B2CNoUPOPTransAmt,0)) B2CNoUPOPTransAmt,
		SUM(ISNULL(AllMerWithBranch.UPOPTransAmt,0)) UPOPTransAmt,
		SUM(ISNULL(AllMerWithBranch.B2BTransAmt,0)) B2BTransAmt,
		SUM(ISNULL(AllMerWithBranch.DeductTransAmt,0)) DeductTransAmt,
		SUM(ISNULL(AllMerWithBranch.ORATransAmt,0)) ORATransAmt
	from
		#AllMerWithBranch AllMerWithBranch
		left join
		#NewlyOpenMer NewlyOpenMer
		on
			AllMerWithBranch.MerchantNo = NewlyOpenMer.MerchantNo
	group by
		AllMerWithBranch.BranchOffice
)
select
	TempResult.BranchOffice,
	TempResult.NewlyIncreMerCount,
	CONVERT(decimal,TempResult.B2CNoUPOPTransCnt)/10000 B2CNoUPOPTransCnt,
	CONVERT(decimal,TempResult.UPOPTransCnt)/10000 UPOPTransCnt,
	CONVERT(decimal,TempResult.B2BTransCnt)/10000 B2BTransCnt,
	CONVERT(decimal,TempResult.DeductTransCnt)/10000 DeductTransCnt,
	CONVERT(decimal,TempResult.ORATransCnt)/10000 ORATransCnt,
	ISNULL(CONVERT(decimal,FundData.TransCnt),0)/10000 FundTransCnt,  
	CONVERT(decimal,TempResult.B2CNoUPOPTransAmt)/1000000 B2CNoUPOPTransAmt,
	CONVERT(decimal,TempResult.UPOPTransAmt)/1000000 UPOPTransAmt,
	CONVERT(decimal,TempResult.B2BTransAmt)/1000000 B2BTransAmt,
	CONVERT(decimal,TempResult.DeductTransAmt)/1000000 DeductTransAmt,
	CONVERT(decimal,TempResult.ORATransAmt)/1000000 ORATransAmt,
	ISNULL(CONVERT(decimal,FundData.TransAmt),0)/1000000 FundTransAmt,  
	CONVERT(decimal,TempResult.B2CNoUPOPTransAmt+TempResult.UPOPTransAmt+TempResult.B2BTransAmt+TempResult.DeductTransAmt+TempResult.ORATransAmt+ISNULL(FundData.TransAmt,0))/1000000 AllData
from
	TempResult
	left join
	#FundData FundData
	on
		TempResult.BranchOffice = FundData.BranchOffice
where  
	TempResult.BranchOffice <> ''  
	or  
	TempResult.BranchOffice <> null  
order by
	CONVERT(decimal,TempResult.B2CNoUPOPTransAmt+TempResult.UPOPTransAmt+TempResult.B2BTransAmt+TempResult.DeductTransAmt+TempResult.ORATransAmt+ISNULL(FundData.TransAmt,0))/1000000 desc;  


--With #Sum as
--(
--	select 
--		SUM(SumTransAmount) WholeSum
--	from 
--		#Result
--)
--select
--	R.BranchOffice,
--	R.NewlyIncreMerCount,
--	R.SumTransCount,
--	R.SumTransAmount,
--	R.SumFundCount,
--	R.SumFundAmount,
--	case when 
--		S.WholeSum = 0
--	then
--		0
--	else
--	CONVERT(decimal,ISNULL(R.SumTransAmount,0)) / S.WholeSum 
--	end Ratio,
--	case when 
--		R.BranchOffice = N'北京数字王府井科技有限公司'
--	then
--		N'数字王府井'
--	when
--		R.BranchOffice = N'北京银联商务有限公司'
--	then
--		N'北京'
--	when
--		R.BranchOffice = N'广州银联网络支付有限公司'
--	then 
--		N'好易联'
--	when
--		R.BranchOffice = N'银联商务有限公司黑龙江分公司'
--	then
--		N'黑龙江'
--	when
--		R.BranchOffice = N'银联商务有限公司内蒙古分公司'
--	then
--		N'内蒙古'
--	else
--		SUBSTRING(R.BranchOffice,9,2)
--	end Area
--from
--	#Result R,
--	#Sum S
--order by
--	R.SumTransAmount desc;


--13. Drop Temp Tables
drop table #PaymentData;
drop table #EmallTransData;
drop table #B2CNoUPOP;
drop table #UPOPData;
drop table #B2BData;
drop table #DeductTransData;
drop table #ORAWUTransData;
drop table #FundData;
drop table #NewlyOpenMer;
drop table #MerWithBranch;
drop table #AllMerWithBranch;

end