--1. ʱ��α�
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
	'2013-08-01',
	'2013-09-01'
);

--2. ���� #WestUnion
select
	CPDate as TransDate,
	MerchantNo,
	'' as Gate,
	SUM(DestTransAmount) as TransAmt,
	COUNT(1) as TransCnt,
	0 as FeeAmt,
	0.0 as CostAmt,
	N'Table_WUTransLog' as Plat,
	N'�������' as Category,
	15 as Rn
into
	#WestUnion
from 
	Table_WUTransLog
where
	CPDate >= (select sd from #DateRange)
	and
	CPDate < (select ed from #DateRange)
group by
	CPDate,
	MerchantNo;

--3. �´��ո�ƽ̨ #TraScreenSum
select
	CPDate as TransDate,
	MerchantNo,
	ChannelNo as Gate,
	CalFeeAmt as TransAmt,
	CalFeeCnt as TransCnt,
	FeeAmt,
	CostAmt,
	N'Table_TraScreenSum' as Plat,
	case when
		TransType in ('100002', '100005')
	then
		N'����'
	when
		TransType in ('100001', '100004')
	then
		N'����'
	else
		N'��ȷ��'	
	end as Category,
	case when
		TransType in ('100002', '100005')
	then
		12
	when
		TransType in ('100001', '100004')
	then
		14
	else
		-1	
	end as Rn
into
	#TraScreenSum
from
	Table_TraScreenSum
where
	CPDate >= (select sd from #DateRange)
	and
	CPDate < (select ed from #DateRange);

--4. �ϴ��� #OraTransSum
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
	declare @sd1 date;
	declare @ed1 date;
	set @sd1 = (select sd from #DateRange);
	set @ed1 = (select ed from #DateRange);

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
		@sd1, 
		@ed1, 
		null
end

select
	OraCost.BankSettingID as Gate,    
	OraCost.MerchantNo,    
	OraCost.CPDate as TransDate,  
	OraCost.TransCnt,  
	OraCost.TransAmt,
	isnull(OraCost.TransCnt * Additional.FeeValue, OraFee.FeeAmount) as FeeAmt,
	OraCost.CostAmt,
	N'Table_OraTransSum' as Plat,
	case when
		OraCost.MerchantNo = '606060290000016'
	then
		N'��ҵ����'
	when
		OraCost.MerchantNo not in ('606060290000016','606060290000015')
	then
		N'����'
	else
		N'�Ӵ����ų�'		
	end as Category,
	case when
		OraCost.MerchantNo = '606060290000016'
	then
		13
	when
		OraCost.MerchantNo not in ('606060290000016','606060290000015')
	then
		12
	else
		-2		
	end as Rn
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
		OraCost.MerchantNo = Additional.MerchantNo;

--5. Upopֱ�� #UpopliqFeeLiqResult
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
	exec Proc_CalUpopCost @sd2, @ed2;
end

select
	u.TransDate,
	u.GateNo as Gate,
	u.MerchantNo,
	u.TransCnt,
	u.TransAmt,
	u.FeeAmt,
	u.CostAmt,
	N'Table_UpopliqFeeLiqResult' as Plat,
	case when 
		u.MerchantNo = '802080290000015'
	then
		N'UPOP_������'
	when
		r.CpMerNo in (select MerchantNo from Table_InstuMerInfo where InstuNo = '999920130320153')
	then
		N'UPOP_UPUP-�ֻ�֧��'
	else
		N'UPOP_UPOP-ֱ��'
	end as Category,
	case when 
		u.MerchantNo = '802080290000015'
	then
		8
	when
		r.CpMerNo in (select MerchantNo from Table_InstuMerInfo where InstuNo = '999920130320153')
	then
		7
	else
		6
	end as Rn
into
	#UpopliqFeeLiqResult
from
	#UpopDirect u
	left join
	Table_CpUpopRelation r
	on
		u.MerchantNo = r.UpopMerNo;
		
--6. ֧����̨ #FeeCalcResult
--6.1 FeeCalcResult������
create table #FeeCalcResult
(
	GateNo char(4),
	MerchantNo Char(20),
	FeeEndDate date,
	TransCnt int,
	TransAmt decimal(20,2),
	CostAmt decimal(20,2),
	FeeAmt decimal(20,2),
	InstuFeeAmt decimal(20,2),
	Plat varchar(40) default('Table_FeeCalcResult'),
	Category nvarchar(40) default(N''),
	Rn int default(-3)
);

if not exists(select 1 from #FeeCalcResult)
begin
	declare @sd3 date;
	declare @ed3 date;
	set @sd3 = (select sd from #DateRange);
	set @ed3 = (select ed from #DateRange);

	insert into #FeeCalcResult
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
	exec Proc_CalPaymentCost @sd3,@ed3,null,'on'
end

--6.2 ����Category ����
update
	f
set
	f.Category = N'����',
	f.Rn = 14
from
	#FeeCalcResult f
where
	f.GateNo in (select GateNo from Table_GateCategory where GateCategory1 = N'����')
	and
	f.Category = N'';

--6.3 ����Category ����������
update
	fcr
set
	fcr.Category = N'����������',
	fcr.Rn = 11
from
	#FeeCalcResult fcr
where
	fcr.GateNo in ('5901','5902')
	and
	fcr.Category = N'';

--6.4 ����Category B2B
update
	fcr
set
	fcr.Category = N'B2B',
	fcr.Rn = 10
from
	#FeeCalcResult fcr
where
	fcr.GateNo in (select GateNo from Table_GateCategory where GateCategory1 = N'B2B')
	and
	fcr.Category = N'';

--6.5 ����Category Epos
update
	fcr
set
	fcr.Category = N'EPOS',
	fcr.Rn = 9
from
	#FeeCalcResult fcr
where
	fcr.GateNo in (select GateNo from Table_GateCategory where GateCategory1 = N'EPOS')
	and
	fcr.Category = N'';

--6.6 ����Category UPOP����
update
	fcr
set
	fcr.Category = N'UPOP_UPOP-����',
	fcr.Rn = 5
from
	#FeeCalcResult fcr
where
	fcr.GateNo in (select GateNo from Table_GateCategory where GateCategory1 = N'UPOP')
	and
	fcr.Category = N'';

--6.7 ����Category ����֧��
update
	fcr
set
	fcr.Category = N'B2C_����֧��',
	fcr.Rn = 4
from
	#FeeCalcResult fcr
where
	fcr.GateNo in ('5601','5602','5603')
	and
	fcr.Category = N'';
	

--6.7 ����Category Ԥ��Ȩ
update
	fcr
set
	fcr.Category = N'B2C_Ԥ��Ȩ',
	fcr.Rn = 3
from
	#FeeCalcResult fcr
where
	fcr.GateNo in (select GateNo from Table_GateCategory where GateCategory1 = N'MOTO')
	and
	fcr.Category = N'';	

--6.8 ����Category B2C-����
update
	fcr
set
	fcr.Category = N'B2C_B2C-����',
	fcr.Rn = 2
from
	#FeeCalcResult fcr
where
	fcr.MerchantNo in (select MerchantNo from Table_MerInfoExt)
	and
	fcr.Category = N'';

--6.9 ����Category B2C-����
update
	fcr
set
	fcr.Category = N'B2C_B2C-����',
	fcr.Rn = 1
from
	#FeeCalcResult fcr
where
	fcr.Category = N'';

--7 FinalResult
With AllTrans as
(
	select
		TransDate,
		MerchantNo,
		Gate,
		TransAmt,
		TransCnt,
		FeeAmt,
		CostAmt,
		Plat,
		Category,
		Rn
	from
		#WestUnion
	union all
	select
		TransDate,
		MerchantNo,
		Gate,
		TransAmt,
		TransCnt,
		FeeAmt,
		CostAmt,
		Plat,
		Category,
		Rn
	from
		#TraScreenSum
	union all
	select
		TransDate,
		MerchantNo,
		Gate,
		TransAmt,
		TransCnt,
		FeeAmt,
		CostAmt,
		Plat,
		Category,
		Rn
	from	
		#OraTransSum
	union all
	select
		TransDate,
		MerchantNo,
		Gate,
		TransAmt,
		TransCnt,
		FeeAmt,
		CostAmt,
		Plat,
		Category,
		Rn
	from
		#UpopliqFeeLiqResult
	union all
	select
		FeeEndDate as TransDate,
		MerchantNo,
		GateNo as Gate,
		TransAmt,
		TransCnt,
		FeeAmt,
		CostAmt,
		Plat,
		Category,
		Rn
	from
		#FeeCalcResult
)
select
	Rn,
	Category,
	SUM(TransAmt)/10000000000.0 as TransAmt,
	SUM(TransCnt)/10000.0 as TransCnt,
	SUM(FeeAmt)/1000000.0 as FeeAmt,
	SUM(CostAmt)/1000000.0 as CostAmt	
from
	AllTrans
group by
	Rn,
	Category
order by
	Rn;
	

--8 Clear temp tables
drop table #DateRange;
drop table #WestUnion;
drop table #TraScreenSum;
drop table #OraCost;
drop table #OraTransSum;
drop table #UpopDirect;
drop table #UpopliqFeeLiqResult;
drop table #FeeCalcResult;