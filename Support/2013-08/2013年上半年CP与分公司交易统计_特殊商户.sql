
--1 create temp table DateRange
create table #DateRange
(
	sd date,
	ed date
);

insert into #DateRange
(
	sd,
	ed
)
values
(
	'2013-01-01',
	'2013-07-01'
);

select * from #DateRange
	
--2 import Special Merchants
exec xprcFile '
MerchantNo	MerchantName
2010000000021	网之易信息技术（北京）有限公司
606060072800044	网之易信息技术（北京）有限公司
808080001000116	网之易信息技术（北京）有限公司
808080051901999	中移电子商务有限公司
808080052202103	网易宝有限公司
808080570005294	中移电子商务有限公司（B2B）
808080570105164	浙江君宝通信科技山东分公司（单笔代扣）
808080570105650	浙江连连科技有限公司（单笔代扣）
808080570106185	浙江君宝通信科技上海分公司（单笔代扣）
808080570106186	浙江君宝杭州分公司（单笔代扣）
808080450103723	海尔集团财务有限公司（B2C大额）
808080450103703	海尔集团财务有限公司
808080580107149	青岛施特劳斯水设备有限公司（预授权）
'

select
	MerchantNo,
	MerchantName
into
	#SpecialMerchants
from
	xlsContainer
	
select * from #SpecialMerchants;

--3 代付
--3.1 #NewOra
select
	MerchantNo,
	ChannelNo,
	CPDate,
	CalFeeAmt,
	CalFeeCnt,
	FeeAmt,
	CostAmt
into
	#NewOra
from
	Table_TraScreenSum
where
	TransType in ('100002', '100005')
	and
	CPDate >= (select sd from #DateRange)
	and
	CPDate < (select ed from #DateRange)
	and
	MerchantNo in (select MerchantNo from #SpecialMerchants);

--3.2 #OldOra
create table #OldOraCost
(
	BankSettingID char(8),
	MerchantNo char(20),
	CPDate datetime,
	TransCnt int,
	TransAmt bigint,
	CostAmt decimal(15,2)
);

declare @sd date;
declare @ed date;
set @sd = (select sd from #DateRange);
set @ed = (select ed from #DateRange);

insert into #OldOraCost
(
	BankSettingID,
	MerchantNo,
	CPDate,
	TransCnt,
	TransAmt,
	CostAmt
)
exec Proc_CalOraCost @sd, @ed, null;

select
	c.BankSettingID,
	c.MerchantNo,
	c.CPDate,
	c.TransCnt,
	c.TransAmt,
	case when 
		a.FeeValue is not null
	then
		c.TransCnt * a.FeeValue
	else
		s.FeeAmount
	end as FeeAmount,		
	c.CostAmt
into
	#OldOra
from
	#OldOraCost c
	inner join
	Table_OraTransSum s
	on
		c.BankSettingID = s.BankSettingID
		and
		c.CPDate = s.CPDate
		and
		c.MerchantNo = s.MerchantNo
	left join
	Table_OraAdditionalFeeRule a
	on
		c.MerchantNo = a.MerchantNo
where
	c.MerchantNo in (select MerchantNo from #SpecialMerchants);

--3.3 #Ora 汇总 #NewOra #OldOra
With Ora as
(	
	select
		N'兴业渠道' CategoryName,
		MerchantNo,
		CalFeeAmt as TransAmt,
		CalFeeCnt as TransCnt,
		FeeAmt,
		CostAmt
	from
		#NewOra
	where
		MerchantNo in ('606060290000015','606060290000016')
	union all
	select
		N'兴业渠道' CategoryName,
		MerchantNo,
		TransAmt,
		TransCnt,
		FeeAmount as FeeAmt,
		CostAmt
	from
		#OldOra
	where
		MerchantNo in ('606060290000015','606060290000016')
	union all
	select
		N'商户代付' CategoryName,
		MerchantNo,
		CalFeeAmt as TransAmt,
		CalFeeCnt as TransCnt,
		FeeAmt,
		CostAmt
	from
		#NewOra
	where
		MerchantNo not in ('606060290000015','606060290000016')	
	union all
	select
		N'商户代付' CategoryName,
		MerchantNo,
		TransAmt,
		TransCnt,
		FeeAmount as FeeAmt,
		CostAmt
	from
		#OldOra
	where
		MerchantNo not in ('606060290000015','606060290000016')
)
select
	CategoryName,
	MerchantNo,
	SUM(TransAmt) as TransAmt,
	SUM(TransCnt) as TransCnt,
	SUM(FeeAmt) as FeeAmt,
	SUM(CostAmt) as CostAmt,
	0 as InstuAmt
into
	#Ora
from
	Ora
group by
	CategoryName,
	MerchantNo;
	
--4 支付、代收、新代收、UPOP直连
--4.1 支付、代收 #PayTrans
create table #PayTrans
(
	GateNo char(4),
	MerchantNo char(20),
	FeeEndDate date,
	TransCnt int,
	TransAmt bigint,
	CostAmt decimal(20,2),
	FeeAmt bigint,
	InstuFeeAmt bigint
);

declare @sd1 date;
declare @ed1 date;
set @sd1 = (select sd from #DateRange);
set @ed1 = (select ed from #DateRange);
insert into #PayTrans
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
	@sd1,
	@ed1,
	null,
	'on';

--4.2 UPOP直连 #UpopDirect
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

declare @sd2 date;
declare @ed2 date;
set @sd2 = (select sd from #DateRange);
set @ed2 = (select ed from #DateRange);
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
exec Proc_CalUPOPCost @sd2,@ed2;

--4.3 商户号、渠道对应表 #MerchantChannel
select
	coalesce(s.MerchantNo, f.MerchantNo) as MerchantNo,
	case when
		coalesce(s.Channel, f.Channel) in (N'银联', N'银商')
	then
		N'分公司'
	else
		N'CP'
	end as Channel
into
	#MerchantChannel
from
	Table_SalesDeptConfiguration s
	full outer join
	Table_FinancialDeptConfiguration f
	on
		s.MerchantNo = f.MerchantNo;

--4.3 Union 支付、代扣、新代扣、UPOP直连 #AllTrans		
select
	p.GateNo as Gate,
	p.MerchantNo,
	p.FeeEndDate as TransDate,
	p.TransCnt,
	p.TransAmt,
	p.CostAmt,
	p.FeeAmt,
	p.InstuFeeAmt as InstuAmt,
	isnull(c.Channel, N'CP') as Channel,
	CONVERT(nvarchar(20), N'') as CategoryName,
	'Pay' as Plat
into
	#AllTrans
from
	#PayTrans p
	left join
	#MerchantChannel c
	on
		p.MerchantNo = c.MerchantNo
where
	p.MerchantNo in (select MerchantNo from #SpecialMerchants)
union all
select
	t.ChannelNo as Gate,
	t.MerchantNo,
	t.CPDate as TransDate,
	t.CalFeeCnt as TransCnt,
	t.CalFeeAmt as TransAmt,
	t.CostAmt,
	t.FeeAmt,
	0 as InstuAmt,
	ISNULL(c.Channel, N'CP') as Channel,
	N'代收_其他代收' as CategoryName,
	'Tra' as Plat
from
	Table_TraScreenSum t
	left join
	#MerchantChannel c
	on
		t.MerchantNo = c.MerchantNo
where
	t.TransType in ('100001', '100004')
	and
	t.CPDate >= (select sd from #DateRange)
	and
	t.CPDate < (select ed from #DateRange)
	and
	t.MerchantNo in (select MerchantNo from #SpecialMerchants)
union all
select
	u.GateNo as Gate,
	ISNULL(r.CpMerNo, u.MerchantNo) as MerchantNo,
	u.TransDate,
	u.TransCnt,
	u.TransAmt,
	u.CostAmt,
	u.FeeAmt,
	0 as InstuAmt,
	ISNULL(c.Channel, N'CP') as Channel,
	CONVERT(nvarchar(20),N'') as CategoryName,
	'UpopDirect' as Plat
from
	#UpopDirect u
	left join
	Table_CpUpopRelation r
	on
		u.MerchantNo = r.UpopMerNo
	left join
	#MerchantChannel c
	on
		ISNULL(r.CpMerNo, u.MerchantNo) = c.MerchantNo
where
	ISNULL(r.CpMerNo, u.MerchantNo) in (select MerchantNo from #SpecialMerchants);

--4.4 标记#AllTrans中的代收
update
	a
set
	a.CategoryName = N'代收_其他代收'
from
	#AllTrans a
where
	a.Gate in (select GateNo from Table_GateCategory where GateCategory1 = N'代扣')
	and
	a.CategoryName = N'';
	
--4.5 标记#AllTrans中的B2B
update
	a
set
	a.CategoryName = N'B2B'
from
	#AllTrans a
where
	a.Gate in (select GateNo from Table_GateCategory where GateCategory1 = N'B2B')
	and
	a.CategoryName = N'';
	
--4.6 标记#AllTrans中的EPOS
update
	a
set
	a.CategoryName = N'EPOS'
from
	#AllTrans a
where
	a.Gate in (select GateNo from Table_GateCategory where GateCategory1 = N'EPOS')
	and
	a.CategoryName = N'';
	
--4.7 标记#AllTrans中“其他接入类” 5901、5902
update
	a
set
	a.CategoryName = N'其他接入类'
from
	#AllTrans a
where
	a.Gate in ('5901', '5902')
	and
	a.CategoryName = N'';
	
--4.8 标记#AllTrans中“UPOP_铁道部” 802080290000015
update
	a
set
	a.CategoryName = N'UPOP_铁道部'
from
	#AllTrans a
where
	a.MerchantNo = '802080290000015'
	and
	a.CategoryName = N'';

--4.9 标记#AllTrans中“UPOP_手机支付-CP”
update
	a
set
	a.CategoryName = N'UPOP_手机支付-CP'
from
	#AllTrans a
where
	a.Plat = 'UpopDirect'
	and
	a.MerchantNo in (select MerchantNo from Table_InstuMerInfo where InstuNo = '999920130320153')
	and
	a.Channel = N'CP'
	and
	a.CategoryName = N'';
	
--4.10 标记#AllTrans中“UPOP_手机支付-分公司”
update
	a
set
	a.CategoryName = N'UPOP_手机支付-分公司'
from
	#AllTrans a
where
	a.Plat = 'UpopDirect'
	and
	a.MerchantNo in (select MerchantNo from Table_InstuMerInfo where InstuNo = '999920130320153')
	and
	a.Channel = N'分公司'
	and
	a.CategoryName = N'';

--4.11 标记#AllTrans中“UPOP_其他-CP”
update
	a
set
	a.CategoryName = N'UPOP_其他-CP'
from
	#AllTrans a
where
	(
		a.Plat = 'UpopDirect'
		or
		a.Gate in (select GateNo from Table_GateCategory where GateCategory1 = N'UPOP')
	)
	and
	a.CategoryName = N''
	and
	a.Channel = 'CP';	

--4.12 标记#AllTrans中“UPOP_其他-分公司”
update
	a
set
	a.CategoryName = N'UPOP_其他-分公司'
from
	#AllTrans a
where
	(
		a.Plat = 'UpopDirect'
		or
		a.Gate in (select GateNo from Table_GateCategory where GateCategory1 = N'UPOP')
	)
	and
	a.CategoryName = N''
	and
	a.Channel = N'分公司';	

--4.13 标记#AllTrans中“B2C_境外”
update
	a
set
	a.CategoryName = N'B2C_境外'
from
	#AllTrans a
where
	a.CategoryName = N''
	and
	a.MerchantNo in (select MerchantNo from Table_MerInfoExt);

--4.14 标记#AllTrans中“B2C_境内-CP”	
update
	a
set
	a.CategoryName = N'B2C_境内-CP'
from
	#AllTrans a
where
	a.CategoryName = N''
	and
	a.Channel = N'CP';

--4.15 标记#AllTrans中“B2C_境内-分公司”	
update
	a
set
	a.CategoryName = N'B2C_境内-分公司'
from
	#AllTrans a
where
	a.CategoryName = N''
	and
	a.Channel = N'分公司';

--5 Group by CategoryName
With SumResult as
(
	select
		a.CategoryName,
		a.MerchantNo,
		SUM(TransAmt) as TransAmt,
		SUM(TransCnt) as TransCnt,
		SUM(FeeAmt) as FeeAmt,
		SUM(CostAmt) as CostAmt,
		SUM(InstuAmt) as InstuAmt
	from
		#AllTrans a
	group by
		a.CategoryName,
		a.MerchantNo
	union all
	select
		CategoryName,
		MerchantNo,
		TransAmt,
		TransCnt,
		FeeAmt,
		CostAmt,
		InstuAmt	
	from
		#Ora
)
select
	s.CategoryName,
	s.MerchantNo,
	(select MerchantName from #SpecialMerchants where MerchantNo = s.MerchantNo) as MerchantName,
	s.TransAmt/10000000000.0 as TransAmt,
	s.TransCnt/10000.0 as TransCnt,
	s.FeeAmt/1000000.0 as FeeAmt,
	s.CostAmt/1000000.0 as CostAmt,
	s.InstuAmt/1000000.0 as InstuAmt
from
	SumResult s
order by
	s.CategoryName,
	s.MerchantNo;






drop table #Ora;
drop table #AllTrans;