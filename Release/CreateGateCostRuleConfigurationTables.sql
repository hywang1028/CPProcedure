--Created by Chen wu on 2011-09-05
--Create Gate Cost Rule Configuration tables

--1. Create and Truncate Table_GateCostRule
if OBJECT_ID(N'Table_GateCostRule', N'U') is null
begin
	create table Table_GateCostRule
	(
		GateCostRuleId int not null identity(1,1),
		GateNo char(4) not null,
		CostRuleType varchar(20) not null, --options: ByTrans, ByYear, ByMer
		ApplyDate datetime not null,
		
		CreatedAt datetime not null default(getdate()),
		ModifiedAt datetime not null default(getdate()),
		
		primary key nonclustered(GateCostRuleId),
		unique clustered(ApplyDate, GateNo)
	);
end
else
begin
	print 'Already exist Table_GateCostRule';
end


--2. Create and Truncate Table_CostRuleByTrans
if OBJECT_ID(N'Table_CostRuleByTrans', N'U') is null
begin
	create table Table_CostRuleByTrans
	(
		CostRuleByTransId int not null identity(1,1),
		GateNo char(4) not null,
		RefMinAmt bigint not null default(0),
		RefMaxAmt bigint not null default(100000000000000),
		FeeType varchar(20) not null, --options: Fixed, Percent
		FeeValue decimal(15,4) not null,
		ApplyDate datetime not null,
		
		CreatedAt datetime not null default(getdate()),
		ModifiedAt datetime not null default(getdate()),
		
		primary key nonclustered(CostRuleByTransId),
		unique clustered(ApplyDate, GateNo, RefMinAmt, RefMaxAmt)
	);
end
else
begin
	print 'Already exist Table_CostRuleByTrans';
end


--3. Create and Truncate Table_CostRuleByYear
if OBJECT_ID(N'Table_CostRuleByYear', N'U') is null
begin
	create table Table_CostRuleByYear
	(
		CostRuleByYearId int not null identity(1,1),
		GateNo char(4) not null,
		RefMinAmt bigint not null default(0),
		RefMaxAmt bigint not null default(100000000000000),
		FeeType varchar(20) not null, --options: Fixed, Percent, Split
		FeeValue decimal(15,4) not null,
		ApplyDate datetime not null,
		GateGroup int not null default(0),
		
		CreatedAt datetime not null default(getdate()),
		ModifiedAt datetime not null default(getdate()),
		
		primary key nonclustered(CostRuleByYearId),
		unique clustered(ApplyDate, GateNo, RefMinAmt, RefMaxAmt)
	);
end
else
begin
	print 'Already exist Table_CostRuleByYear';
end

--4. Create and Truncate Table_CostRuleByMer
if OBJECT_ID(N'Table_CostRuleByMer', N'U') is null
begin
	create table Table_CostRuleByMer
	(
		CostRuleByMerId int not null identity(1,1),
		GateNo char(4) not null,
		MerchantNo char(20) not null,
		FeeType varchar(20) not null, --options: Fixed, Percent
		FeeValue decimal(15,4) not null,
		ApplyDate datetime not null,
		
		CreatedAt datetime not null default(getdate()),
		ModifiedAt datetime not null default(getdate()),
		
		primary key nonclustered(CostRuleByMerId),
		unique clustered(ApplyDate, GateNo, MerchantNo)
	);
end
else
begin
	print 'Already exist Table_CostRuleByMer';
end
