
--Created by Chen.wu on 2013-10-10

if OBJECT_ID(N'Proc_QueryBasicTrans',N'P') is not null
begin
	drop procedure Proc_QueryBasicTrans
end
go

create procedure Proc_QueryBasicTrans
	@FeeStartDate date,
	@FeeEndDate date,
	@TransStartDate date,
	@TransEndDate date
as
begin

----------------测试---------------
--declare @FeeStartDate date;
--declare @FeeEndDate date;
--declare @TransStartDate date;
--declare @TransEndDate date;

--set @FeeStartDate = '2013-07-01';
--set @FeeEndDate = '2013-08-01';
--set @TransStartDate = '2013-07-01';
--set @TransEndDate = '2013-08-01';
-----------------------------------

--1. 设置截止日期
if (ISNULL(@FeeStartDate, N'') = N'' 
	or ISNULL(@FeeEndDate, N'') = N''
	or ISNULL(@TransStartDate, N'') = N''
	or ISNULL(@TransEndDate, N'') = N'')
begin
	raiserror(N'Input params cannot be empty in Proc_QueryBasicTrans',16,1);  
end

set @FeeEndDate = DATEADD(day,1,@FeeEndDate);
set @TransEndDate = DATEADD(day,1,@TransEndDate);


--2. 西联 #WestUnion
select
	N'老代付' as Plat,
	N'西联汇款' as Category,
	
	w.MerchantNo,
	(select MerchantName from Table_OraMerchants where MerchantNo = w.MerchantNo) as MerchantName,
	'' as Gate,
	'' as GateName,
	SUM(w.DestTransAmount) as TransAmt,
	COUNT(1) as TransCnt,
	0 as FeeAmt,
	0.0 as CostAmt
into
	#WestUnion
from 
	Table_WUTransLog w
where
	w.CPDate >= @FeeStartDate
	and
	w.CPDate < @FeeEndDate
group by
	w.MerchantNo;

--3. 新代收付平台 #TraScreenSum
create table #TraCost
(
	MerchantNo char(15),
	ChannelNo char(6),
	TransType varchar(20),
	CPDate date,
	TotalCnt int,
	TotalAmt decimal(15, 2),
	SucceedCnt int,
	SucceedAmt decimal(15,2),
	CalFeeCnt int,
	CalFeeAmt decimal(15,2),
	CalCostCnt int,
	CalCostAmt decimal(15,2),
	FeeAmt decimal(15,2),
	CostAmt decimal(15,2)
);

if not exists(select 1 from #TraCost)
begin
	insert into #TraCost
	(
		MerchantNo,
		ChannelNo,
		TransType,
		CPDate,
		TotalCnt,
		TotalAmt,
		SucceedCnt,
		SucceedAmt,
		CalFeeCnt,
		CalFeeAmt,
		CalCostCnt,
		CalCostAmt,
		FeeAmt,
		CostAmt
	)
	exec Proc_CalTraCost @FeeStartDate,@FeeEndDate;
end;


With TransScreenSum as (
	select
		case when
			TransType in ('100002', '100005')
		then
			N'代付'
		when
			TransType in ('100001', '100004')
		then
			N'代扣'
		else
			N'不确定'	
		end as Category,

		MerchantNo,
		ChannelNo as Gate,
		CalFeeAmt as TransAmt,
		CalFeeCnt as TransCnt,
		FeeAmt,
		CostAmt
	from
		#TraCost
)
select
	N'新代收付' as Plat,
	t.Category,
	
	t.MerchantNo,
	(select MerchantName from Table_TraMerchantInfo where MerchantNo = t.MerchantNo) as MerchantName,
	t.Gate,
	(select ChannelName from Table_TraChannelConfig where ChannelNo = t.Gate) as GateName,
	SUM(t.TransAmt) as TransAmt,
	SUM(t.TransCnt) as TransCnt,
	SUM(t.FeeAmt) as FeeAmt,
	SUM(t.CostAmt) as CostAmt
into
	#TraScreenSum
from
	TransScreenSum t
group by
	t.Category,
	t.MerchantNo,
	t.Gate;


--4. 老代付 #OraTransSum
create table #OraCost
(
	BankSettingID char(8),    
	MerchantNo char(20),    
	CPDate date,  
	TransCnt int,  
	TransAmt bigint,  
	CostAmt decimal(20,2)  
);

if not exists(select 1 from #OraCost)
begin
	insert into #OraCost
	(
		BankSettingID,    
		MerchantNo,    
		CPDate,  
		TransCnt,  
		TransAmt,  
		CostAmt
	)
	exec Proc_CalOraCost 
		@FeeStartDate, 
		@FeeEndDate, 
		null
end

select
	N'老代付' as Plat,
	case when
		OraCost.MerchantNo in ('606060290000015','606060290000016','606060290000017')
	then
		N'代付_兴业渠道'
	else
		N'代付'		
	end as Category,

	OraCost.MerchantNo,
	(select MerchantName from Table_OraMerchants where MerchantNo = OraCost.MerchantNo) as MerchantName,
	OraCost.BankSettingID as Gate,
	(select BankName from Table_OraBankSetting where BankSettingID = OraCost.BankSettingID) as GateName,    
	sum(OraCost.TransCnt) as TransCnt,  
	sum(OraCost.TransAmt) as TransAmt,
	sum(isnull(OraCost.TransCnt * Additional.FeeValue, OraFee.FeeAmount)) as FeeAmt,
	sum(OraCost.CostAmt) as CostAmt
into
	#OraTransSum
from
	#OraCost OraCost
	inner join
	Table_OraTransSum OraFee
	on
		OraCost.BankSettingID = OraFee.BankSettingID
		and
		OraCost.CPDate = OraFee.CPDate
		and
		OraCost.MerchantNo = OraFee.MerchantNo
	left join
	Table_OraAdditionalFeeRule Additional
	on
		OraCost.MerchantNo = Additional.MerchantNo
group by
	OraCost.MerchantNo,
	OraCost.BankSettingID;
	
--5. Upop直连 #UpopliqFeeLiqResult
create table #UpopDirect
(
	GateNo char(4),
	MerchantNo char(20),
	TransDate date,
	CdFlag char(2),
	TransAmt bigint,
	TransCnt int,
	FeeAmt bigint,
	CostAmt decimal(20,2)
);

if not exists(select 1 from #UpopDirect)
begin
	insert into #UpopDirect
	(
		GateNo,
		MerchantNo,
		TransDate,
		CdFlag,
		TransAmt,
		TransCnt,
		FeeAmt,
		CostAmt
	)
	exec Proc_CalUpopCost @FeeStartDate, @FeeEndDate;
end

select
	N'UPOP直连' as Plat,
	case when 
		u.MerchantNo = '802080290000015'
	then
		N'UPOP直连_铁道部'
	when
		u.MerchantNo in (select 
							r.UpopMerNo
						from 
							Table_InstuMerInfo i
							inner join
							Table_CpUpopRelation r
							on
								i.MerchantNo = r.CpMerNo
						where 
							i.InstuNo = '999920130320153' 
							and 
							i.Stat = 1)
	then
		N'UPOP直连_手机支付'
	else
		N'UPOP直连'
	end as Category,
		
	u.MerchantNo,
	isnull((select CpMerNo from Table_CpUpopRelation where UpopMerNo = u.MerchantNo),u.MerchantNo) as CpMerNo,
	(select MerchantName from Table_UpopliqMerInfo where MerchantNo = u.MerchantNo) as MerchantName,
	u.GateNo as Gate,
	(select GateDesc from Table_UpopliqGateRoute where GateNo = u.GateNo) as GateName,
	sum(u.TransCnt) as TransCnt,
	sum(u.TransAmt) as TransAmt,
	sum(u.FeeAmt) as FeeAmt,
	sum(u.CostAmt) as CostAmt
into
	#UpopliqFeeLiqResult
from
	#UpopDirect u
group by
	u.MerchantNo,
	u.GateNo;
	
--6. 支付控台 #FeeCalcResult
--6.1 FeeCalcResult总数据
create table #PaymentCost
(
	GateNo char(4),
	MerchantNo Char(20),
	FeeEndDate date,
	TransCnt int,
	TransAmt decimal(20,2),
	CostAmt decimal(20,2),
	FeeAmt decimal(20,2),
	InstuFeeAmt decimal(20,2)
);

if not exists(select 1 from #PaymentCost)
begin
	insert into #PaymentCost
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
	exec Proc_CalPaymentCost @FeeStartDate,@FeeEndDate,null,'on'
end;

--6.2 添加Plat, Category, MerchantName, GateName属性信息
With Fact as
(
	select
		MerchantNo,
		GateNo,
		SUM(SucceedTransCount) TCnt,
		SUM(SucceedTransAmount) TAmt
	from
		FactDailyTrans
	where
		DailyTransDate >= @TransStartDate
		and
		DailyTransDate < @TransEndDate
		and
		GateNo <> '0000'
	group by
		MerchantNo,
		GateNo
),
Ret as
(
	select
		MerchantNo,
		GateNo,
		SUM(RefAmt) RefAmt
	from
		Table_FeeCalcResult
	where
		FeeEndDate >= @FeeStartDate
		and
		FeeEndDate < @FeeEndDate
		and
		GateNo <> '0000'
	group by
		MerchantNo,
		GateNo		
),
Fee as
(
	select		
		p.MerchantNo,
		p.GateNo,		
		SUM(p.TransCnt) as TransCnt,
		SUM(p.TransAmt) as TransAmt,
		SUM(p.CostAmt) as CostAmt,
		SUM(p.FeeAmt) as FeeAmt
	from
		#PaymentCost p
	where
		p.GateNo <> '0000'
	group by
		p.MerchantNo,
		p.GateNo
)
select
	N'支付控台' as Plat,
	(select GateCategory2 from Table_GateCategory where GateNo = isnull(Fact.GateNo, Fee.GateNo)) as Category,
	
	isnull(Fact.MerchantNo, Fee.MerchantNo) as MerchantNo,
	(select MerchantName from Table_MerInfo where MerchantNo = isnull(Fact.MerchantNo, Fee.MerchantNo)) as MerchantName,
	isnull(Fact.GateNo, Fee.GateNo) as Gate,
	(select GateAlias from Table_GateRoute where GateNo = isnull(Fact.GateNo, Fee.GateNo)) as GateName,
	isnull(Fee.TransCnt, 0) as TransCnt,
	isnull(Fee.TransAmt, 0) as TransAmt,
	isnull(Fee.CostAmt, 0) as CostAmt,
	isnull(Fee.FeeAmt, 0) as FeeAmt,
	ISNULL(Ret.RefAmt, 0) as RefAmt,
	isnull(Fact.TAmt, 0) as TAmt,
	isnull(Fact.TCnt, 0) as TCnt
into
	#FeeCalcResult
from
	Fact
	full outer join
	Fee
	on
		Fact.MerchantNo = Fee.MerchantNo
		and
		Fact.GateNo = Fee.GateNo
	left join
	Ret
	on
		Fee.MerchantNo = Ret.MerchantNo
		and
		Fee.GateNo = Ret.GateNo;


--7. 转账
select
	N'转账' as Plat,
	N'转账' as Category,

	trf.MerchantNo,
	(select MerchantName from Table_MerInfo where MerchantNo = trf.MerchantNo) as MerchantName,
	'' as Gate,
	'' as GateName,    
	count(1) as TransCnt,  
	sum(trf.TransAmt) as TransAmt,
	0 as FeeAmt,
	0 as CostAmt
into
	#TrfTrans
from
	Table_TrfTransLog trf
where
	trf.TransDate >= @FeeStartDate
	and
	trf.TransDate < @FeeEndDate
	and
	trf.TransType in ('2070')
group by
	trf.MerchantNo;

--8. 基金
With TrfFund as
(
	select
		trf.TransType,
		trf.MerchantNo,
		case when 
			trf.TransType in ('1010', '3010')
		then
			trf.CardID
		else
			trf.CardTwo
		end as CardNo,
		trf.TransAmt
	from
		Table_TrfTransLog trf
	where
		trf.TransDate >= @FeeStartDate
		and
		trf.TransDate < @FeeEndDate
		and
		trf.TransType in ('1010', '3010', '3020', '3030', '3040', '3050')
),
TrfFundWithCardBin as
(
	select
		trf.TransType,
		trf.MerchantNo,
		bin.BankNo,
		trf.TransAmt
	from
		TrfFund trf
		left join
		Table_FundCardBin bin
		on
			trf.CardNo like (RTRIM(bin.CardBin)+'%')
)
select
	N'转账' as Plat,
	N'基金_'
		+ case trf.TransType 
			when '1010' then N'开户' 
			when '3010' then N'申购'
			when '3020' then N'撤单'
			when '3030' then N'赎回'
			when '3040' then N'分红'
			when '3050' then N'定投'
			else '其他' end as Category,
	trf.MerchantNo,
	(select MerchantName from Table_MerInfo where MerchantNo = trf.MerchantNo) as MerchantName,
	isnull(trf.BankNo, N'') as Gate,
	isnull((select BankName from Table_BankID where BankNo = trf.BankNo),N'') as GateName,    
	count(1) as TransCnt,  
	sum(trf.TransAmt) as TransAmt,
	0 as FeeAmt,
	0 as CostAmt
into
	#FundTrans
from
	TrfFundWithCardBin trf
group by
	trf.TransType,
	trf.MerchantNo,
	trf.BankNo;

--9. FinalResult
With AllTrans as
(
	select
		Plat,
		Category,
			
		MerchantNo,
		MerchantNo as CpMerNo,
		MerchantName,
		Gate,
		GateName,
		'' as BankName,
		TransAmt,
		TransCnt,
		FeeAmt,
		CostAmt,
		null as RefAmt,
		TransAmt as TAmt,
		TransCnt as TCnt
	from
		#WestUnion
	union all
	select
		Plat,
		Category,	
	
		MerchantNo,
		MerchantNo as CpMerNo,
		MerchantName,
		Gate,
		GateName,
		'' as BankName,
		TransAmt,
		TransCnt,
		FeeAmt,
		CostAmt,
		null as RefAmt,
		TransAmt as TAmt,
		TransCnt as TCnt
	from
		#TraScreenSum
	union all
	select
		Plat,
		Category,
	
		MerchantNo,
		MerchantNo as CpMerNo,
		MerchantName,
		Gate,
		GateName,
		'' as BankName,
		TransAmt,
		TransCnt,
		FeeAmt,
		CostAmt,
		null as RefAmt,
		TransAmt as TAmt,
		TransCnt as TCnt
	from	
		#OraTransSum
	union all
	select
		Plat,
		Category,

		MerchantNo,
		CpMerNo,
		MerchantName,
		Gate,
		GateName,
		'' as BankName,
		TransAmt,
		TransCnt,
		FeeAmt,
		CostAmt,
		null as RefAmt,
		TransAmt as TAmt,
		TransCnt as TCnt
	from
		#UpopliqFeeLiqResult
	union all
	select
		Plat,
		Category,

		MerchantNo,
		MerchantNo as CpMerNo,
		MerchantName,
		Gate,
		GateName,
		(select BankName from Table_GateCategory where GateNo = f.Gate) as BankName,
		TransAmt,
		TransCnt,
		FeeAmt,
		CostAmt,
		RefAmt,
		TAmt,
		TCnt
	from
		#FeeCalcResult f
	union all
	select
		Plat,
		Category,
	
		MerchantNo,
		MerchantNo as CpMerNo,
		MerchantName,
		Gate,
		GateName,
		'' as BankName,
		TransAmt,
		TransCnt,
		FeeAmt,
		CostAmt,
		null as RefAmt,
		TransAmt as TAmt,
		TransCnt as TCnt	
	from
		#TrfTrans
	union all
	select
		Plat,
		Category,
	
		MerchantNo,
		MerchantNo as CpMerNo,
		MerchantName,
		Gate,
		GateName,
		'' as BankName,
		TransAmt,
		TransCnt,
		FeeAmt,
		CostAmt,
		null as RefAmt,
		TransAmt as TAmt,
		TransCnt as TCnt	
	from
		#FundTrans	
)
select
	a.Plat,
	a.Category,

	a.MerchantNo,
	a.CpMerNo,
	a.MerchantName,
	a.Gate,
	a.GateName,
	a.BankName,
	a.TransAmt/100.0 as TransAmt,
	a.TransCnt as TransCnt,
	a.FeeAmt/100.0 as FeeAmt,
	a.RefAmt/100.0 as RefAmt,
	a.CostAmt/100.0 as CostAmt,
	(a.FeeAmt - a.CostAmt)/100.0 as Profit,
	a.TAmt/100.0 as TAmt,
	a.TCnt as TCnt,
	coalesce(f.IndustryName, m.IndustryName, N'') as IndustryName,
	coalesce(f.Area, s.Area, N'') as Area,
	coalesce(f.Channel, s.Channel, N'') as DevelopChannel,
	coalesce(f.BranchOffice, s.BranchOffice, N'') as DevelopBranchOffice,
	ISNULL(s.SalesManager, N'') as CustomerManager,
	c.SignDate,
	convert(date, o.OpenAccountDate) as OpenAccountDate,
	isnull(c.MerchantSubject, N'') as MerchantSubject,
	isnull(c.LiquidationCycle, N'') as LiquidationCycle,
	
	case when a.Category in (N'西联汇款') or a.Plat in (N'转账') or a.TransCnt = 0 or a.TransAmt = 0
		then null
	when a.Category in (N'代付', N'代扣', N'B2B')
		then (a.FeeAmt/100.0)/a.TransCnt
	else
		a.FeeAmt/a.TransAmt
	end as AvgFeeRate,
	
	case when a.Category in (N'西联汇款') or a.Plat in (N'转账') or a.TransCnt = 0 or a.TransAmt = 0
		then null
	when a.Category in (N'代付', N'代扣', N'B2B')
		then (a.CostAmt/100.0)/a.TransCnt
	else
		a.CostAmt/a.TransAmt
	end as AvgCostRate
from
	AllTrans a
	left join
	Table_FinancialDeptConfiguration f
	on
		a.CpMerNo = f.MerchantNo
	left join
	Table_SalesDeptConfiguration s
	on
		a.CpMerNo = s.MerchantNo
	left join
	Table_MerAttribute m
	on
		a.CpMerNo = m.MerchantNo
	left join
	Table_MerOpenAccountInfo o
	on
		a.CpMerNo = o.MerchantNo
	outer apply
	(select top(1) 
		SignDate,
		OpenAccountDate,
		MerchantSubject,
		LiquidationCycle  
	from 
		Table_CrmMerInfo 
	where 
		MerchantNo = a.MerchantNo) c; 

--8 Clear temp tables
drop table #PaymentCost;
drop table #TraCost;
drop table #WestUnion;
drop table #TraScreenSum;
drop table #OraCost;
drop table #OraTransSum;
drop table #UpopDirect;
drop table #UpopliqFeeLiqResult;
drop table #FeeCalcResult;
drop table #TrfTrans;
drop table #FundTrans;

end