
if OBJECT_ID(N'Table_CostRuleFixed', N'U') is null
begin
	create table Table_CostRuleFixed
	(
		GateNo char(4) not null,
		FeeValue decimal(15,2) not null,
		ApplyDate datetime not null,
		
		CreatedAt datetime default(getdate()),
		ModifiedAt datetime default(getdate()),
		primary key(ApplyDate, GateNo)
	);
end

if OBJECT_ID(N'Table_CostRulePercent', N'U') is null
begin
	create table Table_CostRulePercent
	(
		GateNo char(4) not null,
		FeeValue decimal(15,4) not null,
		ApplyDate datetime not null,
		
		CreatedAt datetime default(getdate()),
		ModifiedAt datetime default(getdate()),
		primary key(ApplyDate, GateNo)
	);
end

if OBJECT_ID(N'Table_CostRuleSectionByTrans', N'U') is null
begin
	create table Table_CostRuleSectionByTrans
	(
		GateNo char(4) not null,
		RefMinAmt decimal(15,2) not null default(0),
		RefMaxAmt decimal(15,2) not null default(1000000000000.00),
		FeeType varchar(20) not null,
		FeeValue decimal(15,4) not null,
		ApplyDate datetime not null,
		
		CreatedAt datetime default(getdate()),
		ModifiedAt datetime default(getdate()),
		primary key(ApplyDate, GateNo, RefMinAmt, RefMaxAmt)
	);
end

if OBJECT_ID(N'Table_CostRuleSectionByYear', N'U') is null
begin
	create table Table_CostRuleSectionByYear
	(
		GateNo varchar(100) not null,
		RefMinAmt decimal(15,2) not null default(0),
		RefMaxAmt decimal(15,2) not null default(10000000000000.00),
		FeeType varchar(20) not null,
		FeeValue decimal(15,2) not null,
		ApplyDate datetime not null,
		
		CreatedAt datetime default(getdate()),
		ModifiedAt datetime default(getdate()),
		primary key(ApplyDate, GateNo, RefMinAmt, RefMaxAmt)
	);
end

if OBJECT_ID(N'Table_CostRuleByMerchant', N'U') is null
begin
	create table Table_CostRuleByMerchant
	(
		GateNo char(4) not null,
		MerchantNo varchar(20) not null,
		FeeType varchar(20) not null,
		FeeValue decimal(15,2) not null,
		ApplyDate datetime not null,
		
		CreatedAt datetime default(getdate()),
		ModifiedAt datetime default(getdate()),
		primary key(ApplyDate, GateNo, MerchantNo)
	);
end

if OBJECT_ID(N'Table_CostRuleProfitSplit', N'U') is null
begin
create table Table_CostRuleProfitSplit
(
	GateNo char(4) not null,
	ProfitPercent decimal(15, 4) not null default(0),
	ApplyDate datetime not null,
	
	CreatedAt datetime default(getdate()),
	ModifiedAt datetime default(getdate()),
	primary key(ApplyDate, GateNo)
);
end

