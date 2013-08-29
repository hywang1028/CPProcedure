
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
2010000000021	��֮����Ϣ���������������޹�˾
606060072800044	��֮����Ϣ���������������޹�˾
808080001000116	��֮����Ϣ���������������޹�˾
808080051901999	���Ƶ����������޹�˾
808080052202103	���ױ����޹�˾
808080570005294	���Ƶ����������޹�˾��B2B��
808080570105164	�㽭����ͨ�ſƼ�ɽ���ֹ�˾�����ʴ��ۣ�
808080570105650	�㽭�����Ƽ����޹�˾�����ʴ��ۣ�
808080570106185	�㽭����ͨ�ſƼ��Ϻ��ֹ�˾�����ʴ��ۣ�
808080570106186	�㽭�������ݷֹ�˾�����ʴ��ۣ�
808080450103723	�������Ų������޹�˾��B2C��
808080450103703	�������Ų������޹�˾
808080580107149	�ൺʩ����˹ˮ�豸���޹�˾��Ԥ��Ȩ��
'

select
	MerchantNo,
	MerchantName
into
	#SpecialMerchants
from
	xlsContainer
	
select * from #SpecialMerchants;

--3 ����
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

--3.3 #Ora ���� #NewOra #OldOra
With Ora as
(	
	select
		N'��ҵ����' CategoryName,
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
		N'��ҵ����' CategoryName,
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
		N'�̻�����' CategoryName,
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
		N'�̻�����' CategoryName,
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
	
--4 ֧�������ա��´��ա�UPOPֱ��
--4.1 ֧�������� #PayTrans
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

--4.2 UPOPֱ�� #UpopDirect
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

--4.3 �̻��š�������Ӧ�� #MerchantChannel
select
	coalesce(s.MerchantNo, f.MerchantNo) as MerchantNo,
	case when
		coalesce(s.Channel, f.Channel) in (N'����', N'����')
	then
		N'�ֹ�˾'
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

--4.3 Union ֧�������ۡ��´��ۡ�UPOPֱ�� #AllTrans		
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
	N'����_��������' as CategoryName,
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

--4.4 ���#AllTrans�еĴ���
update
	a
set
	a.CategoryName = N'����_��������'
from
	#AllTrans a
where
	a.Gate in (select GateNo from Table_GateCategory where GateCategory1 = N'����')
	and
	a.CategoryName = N'';
	
--4.5 ���#AllTrans�е�B2B
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
	
--4.6 ���#AllTrans�е�EPOS
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
	
--4.7 ���#AllTrans�С����������ࡱ 5901��5902
update
	a
set
	a.CategoryName = N'����������'
from
	#AllTrans a
where
	a.Gate in ('5901', '5902')
	and
	a.CategoryName = N'';
	
--4.8 ���#AllTrans�С�UPOP_�������� 802080290000015
update
	a
set
	a.CategoryName = N'UPOP_������'
from
	#AllTrans a
where
	a.MerchantNo = '802080290000015'
	and
	a.CategoryName = N'';

--4.9 ���#AllTrans�С�UPOP_�ֻ�֧��-CP��
update
	a
set
	a.CategoryName = N'UPOP_�ֻ�֧��-CP'
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
	
--4.10 ���#AllTrans�С�UPOP_�ֻ�֧��-�ֹ�˾��
update
	a
set
	a.CategoryName = N'UPOP_�ֻ�֧��-�ֹ�˾'
from
	#AllTrans a
where
	a.Plat = 'UpopDirect'
	and
	a.MerchantNo in (select MerchantNo from Table_InstuMerInfo where InstuNo = '999920130320153')
	and
	a.Channel = N'�ֹ�˾'
	and
	a.CategoryName = N'';

--4.11 ���#AllTrans�С�UPOP_����-CP��
update
	a
set
	a.CategoryName = N'UPOP_����-CP'
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

--4.12 ���#AllTrans�С�UPOP_����-�ֹ�˾��
update
	a
set
	a.CategoryName = N'UPOP_����-�ֹ�˾'
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
	a.Channel = N'�ֹ�˾';	

--4.13 ���#AllTrans�С�B2C_���⡱
update
	a
set
	a.CategoryName = N'B2C_����'
from
	#AllTrans a
where
	a.CategoryName = N''
	and
	a.MerchantNo in (select MerchantNo from Table_MerInfoExt);

--4.14 ���#AllTrans�С�B2C_����-CP��	
update
	a
set
	a.CategoryName = N'B2C_����-CP'
from
	#AllTrans a
where
	a.CategoryName = N''
	and
	a.Channel = N'CP';

--4.15 ���#AllTrans�С�B2C_����-�ֹ�˾��	
update
	a
set
	a.CategoryName = N'B2C_����-�ֹ�˾'
from
	#AllTrans a
where
	a.CategoryName = N''
	and
	a.Channel = N'�ֹ�˾';

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