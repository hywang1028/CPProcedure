--1. 时间段表
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
	'2012-07-01',
	'2012-10-01'
);

--2. 西联 #WestUnion
select
	CPDate as TransDate,
	MerchantNo,
	'' as Gate,
	SUM(DestTransAmount) as TransAmt,
	COUNT(1) as TransCnt,
	0 as FeeAmt,
	0.0 as CostAmt,
	N'Table_WUTransLog' as Plat,
	N'西联汇款' as Category,
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
	declare @sd0 date;
	declare @ed0 date;
	set @sd0 = (select sd from #DateRange);
	set @ed0 = (select ed from #DateRange);

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
	exec Proc_CalTraCost
		@sd0,
		@ed0;
end;

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
		N'代付'
	when
		TransType in ('100001', '100004')
	then
		N'代收'
	else
		N'不确定'	
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
	#TraCost;

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
		N'兴业渠道'
	when
		OraCost.MerchantNo not in ('606060290000016','606060290000015')
	then
		N'代付'
	else
		N'从代付排除'		
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
		N'UPOP_铁道部'
	when
		r.CpMerNo in (select MerchantNo from Table_InstuMerInfo where InstuNo = '999920130320153')
	then
		N'UPOP_UPUP-手机支付'
	else
		N'UPOP_UPOP-直连'
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
		
--6. 支付控台 #FeeCalcResult
--6.1 FeeCalcResult总数据
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

--6.2 更新Category 代收
update
	f
set
	f.Category = N'代收',
	f.Rn = 14
from
	#FeeCalcResult f
where
	f.GateNo in (select GateNo from Table_GateCategory where GateCategory1 = N'代扣')
	and
	f.Category = N'';

--6.3 更新Category 其他接入类
update
	fcr
set
	fcr.Category = N'其他接入类',
	fcr.Rn = 11
from
	#FeeCalcResult fcr
where
	fcr.GateNo in ('5901','5902')
	and
	fcr.Category = N'';

--6.4 更新Category B2B
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

--6.5 更新Category Epos
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

--6.6 更新Category UPOP间连
update
	fcr
set
	fcr.Category = N'UPOP_UPOP-间连',
	fcr.Rn = 5
from
	#FeeCalcResult fcr
where
	fcr.GateNo in (select GateNo from Table_GateCategory where GateCategory1 = N'UPOP')
	and
	fcr.Category = N'';

--6.7 更新Category 信用支付
update
	fcr
set
	fcr.Category = N'B2C_信用支付',
	fcr.Rn = 4
from
	#FeeCalcResult fcr
where
	fcr.GateNo in ('5601','5602','5603')
	and
	fcr.Category = N'';
	

--6.7 更新Category 预授权
update
	fcr
set
	fcr.Category = N'B2C_预授权',
	fcr.Rn = 3
from
	#FeeCalcResult fcr
where
	fcr.GateNo in (select GateNo from Table_GateCategory where GateCategory1 = N'MOTO')
	and
	fcr.Category = N'';	

--6.8 更新Category B2C-境外
update
	fcr
set
	fcr.Category = N'B2C_B2C-境外',
	fcr.Rn = 2
from
	#FeeCalcResult fcr
where
	fcr.MerchantNo in (select MerchantNo from Table_MerInfoExt)
	and
	fcr.Category = N'';

--6.9 更新Category B2C-境内
update
	fcr
set
	fcr.Category = N'B2C_B2C-境内',
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
drop table #TraCost;