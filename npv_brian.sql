-- STEP 1: create draw table

drop table if exists all_draws;

SELECT
    l.loan_id
    ,l.account_id
    ,dr1.draw_request_id as draw1
    ,dr2.draw_request_id as draw2
    ,dr3.draw_request_id as draw3
    ,dr4.draw_request_id as draw4
    ,dr5.draw_request_id as draw5
    ,dr6.draw_request_id as draw6
    ,dr2.funding_date-dr1.funding_date as time_between_1_2
    ,dr3.funding_date-dr2.funding_date as time_between_2_3
    ,dr4.funding_date-dr3.funding_date as time_between_3_4
    ,dr5.funding_date-dr4.funding_date as time_between_4_5
    ,dr6.funding_date-dr5.funding_date as time_between_5_6
    into temp all_draws
FROM nbox_portfolio_portfolio.loans l
INNER JOIN hd_operations.headway_reporting hr using (loan_id)
LEFT JOIN nbox_portfolio_portfolio.draw_requests dr1
    ON dr1.draw_request_id = (SELECT min(draw_request_id)
        FROM nbox_portfolio_portfolio.draw_requests
        WHERE loan_id = l.loan_id
        AND pending = FALSE
        )
LEFT JOIN nbox_portfolio_portfolio.draw_requests dr2
    ON dr2.draw_request_id = (SELECT min(draw_request_id)
        FROM nbox_portfolio_portfolio.draw_requests
        WHERE loan_id = l.loan_id
            AND draw_request_id > dr1.draw_request_id
            AND pending = FALSE
        )
LEFT JOIN nbox_portfolio_portfolio.draw_requests dr3
    ON dr3.draw_request_id = (SELECT min(draw_request_id)
        FROM nbox_portfolio_portfolio.draw_requests
        WHERE loan_id = l.loan_id
            AND draw_request_id > dr2.draw_request_id
            AND pending = FALSE
        )
 left join nbox_portfolio_portfolio.draw_requests dr4
      on dr4.draw_request_id = (select min(draw_request_id)
          from nbox_portfolio_portfolio.draw_requests
          where loan_id = l.loan_id
              and draw_request_id > dr3.draw_request_id
              and pending= false
          )
  left join nbox_portfolio_portfolio.draw_requests dr5
  on dr5.draw_request_id = (select min(draw_request_id)
  from nbox_portfolio_portfolio.draw_requests
  where loan_id = l.loan_id
  and draw_request_id > dr4.draw_request_id
  and pending= false
  )

  left join nbox_portfolio_portfolio.draw_requests dr6
  on dr6.draw_request_id = (select min(draw_request_id)
  from nbox_portfolio_portfolio.draw_requests
  where loan_id = l.loan_id
  and draw_request_id > dr5.draw_request_id
  and pending= false
  )




  -- STEP 2: create flags for accounting definitions, this part of the query is from accounting reporting queries
  drop table if exists account_flags;
  create temporary table account_flags (account_cd text, account_type text);

  insert into account_flags values
  ('unrecognized_interest_current','Other')
  ,('interest_current','AR')
  ,('principal_called_due','AR')
  ,('unrecognized_interest_revenue','Other')
  ,('fee_revenue','Revenue')
  ,('unrecognized_interest_past_due','Other')
  ,('interest_past_due','AR')
  ,('fee_past_due','AR')
  ,('customer_payable','AR')
  ,('principal_past_due','AR')
  ,('interest_revenue','Revenue')
  ,('principal_current','AR')
  ,('cash','Cash')
  ,('fee_current','AR');
  ;


-- STEP 3: join all the neccesary accounting tables to calcualte the principal/interest/draw breakdown of each payment

 drop table if exists accounting_table;

SELECT
  e.entry_id
  ,a.source_id as loan_id
 ,l.account_id
  ,l.loan_number
  ,l.product_id
  ,a.accounting_date
  ,a.effective_date
  ,a.activity_id
  ,a.cancels_activity_id
  ,at.activity_type
  ,acct.account as debit_account_cd
  ,acct2.account as credit_account_cd
  ,ad.account_type as debit_account_type
  ,ac.account_type as credit_account_type
  ,e.amount
  into temp accounting_table
FROM nbox_portfolio_accounting.entries e
INNER JOIN nbox_portfolio_accounting.activities a on a.activity_id = e.activity_id
inner join nbox_portfolio_accounting.activity_types at on a.activity_type_id = at.activity_type_id
inner join nbox_portfolio_accounting.entry_types et on e.entry_type_id = et.entry_type_id
inner join nbox_portfolio_accounting.accounts acct on et.debit_account_id = acct.account_id
inner join nbox_portfolio_accounting.accounts acct2 on et.credit_account_id = acct2.account_id
inner join nbox_portfolio_accounting.ledgers lg on e.ledger_id=lg.ledger_id
left outer join account_flags ad on ad.account_cd = acct.account
left outer join account_flags ac on ac.account_cd = acct2.account
inner join nbox_portfolio_portfolio.loans l on l.loan_id = a.source_id
  where l.product_id = 6
  and lg.ledger = 'financial'
  order by a.effective_date
;





-- STEP 4: calculate the principal AR at the time of each draw for each LOC

drop table if exists draw_principal_ar;

  select
  ad.loan_id

  ,sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < dr1.funding_date then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < dr1.funding_date then pp.amount else 0 end)
  as total_principal_ar_until_draw1
  ,sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < dr2.funding_date then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < dr2.funding_date then pp.amount else 0 end)
  as total_principal_ar_until_draw2
  ,sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < dr3.funding_date then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < dr3.funding_date then pp.amount else 0 end)
  as total_principal_ar_until_draw3
  ,sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < dr4.funding_date then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < dr4.funding_date then pp.amount else 0 end)
  as total_principal_ar_until_draw4
  ,sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < dr5.funding_date then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < dr5.funding_date then pp.amount else 0 end)
  as total_principal_ar_until_draw5
  ,sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < dr6.funding_date then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < dr6.funding_date then pp.amount else 0 end)
  as total_principal_ar_until_draw6

  into temp draw_principal_ar


  from all_draws ad

  left join nbox_portfolio_portfolio.draw_requests dr1
  on dr1.draw_request_id = ad.draw1
  left join nbox_portfolio_portfolio.draw_requests dr2
  on dr2.draw_request_id = ad.draw2
  left join nbox_portfolio_portfolio.draw_requests dr3
  on dr3.draw_request_id = ad.draw3
  left join nbox_portfolio_portfolio.draw_requests dr4
  on dr4.draw_request_id = ad.draw4
  left join nbox_portfolio_portfolio.draw_requests dr5
  on dr5.draw_request_id = ad.draw5
  left join nbox_portfolio_portfolio.draw_requests dr6
  on dr6.draw_request_id = ad.draw6

  inner join accounting_table pp
  on pp.loan_id = ad.loan_id

  group by 1
  ;


-- STEP 5: create a table storing draw amounts
  drop table if exists draw_amounts;

  select

  l.loan_id
  ,hr.original_credit_limit as credit_limit
  ,dr1.amount as draw1_amount
  ,dr2.amount as draw2_amount
  ,dr3.amount as draw3_amount
  ,dr4.amount as draw4_amount
  ,dr5.amount as draw5_amount
  ,dr6.amount as draw6_amount
  into temp draw_amounts
  from all_draws ad

  left join nbox_portfolio_portfolio.draw_requests dr1
  on dr1.draw_request_id = ad.draw1
  left join nbox_portfolio_portfolio.draw_requests dr2
  on dr2.draw_request_id = ad.draw2
  left join nbox_portfolio_portfolio.draw_requests dr3
  on dr3.draw_request_id = ad.draw3
  left join nbox_portfolio_portfolio.draw_requests dr4
  on dr4.draw_request_id = ad.draw4
  left join nbox_portfolio_portfolio.draw_requests dr5
  on dr5.draw_request_id = ad.draw5
  left join nbox_portfolio_portfolio.draw_requests dr6
  on dr6.draw_request_id = ad.draw6

  inner join nbox_portfolio_portfolio.loans l
  on l.loan_id = ad.loan_id

  inner join hd_operations.headway_reporting hr on l.loan_id = hr.loan_id


  ;

-- STEP 6: create a table draw amount as percentace of remaining credit limit

select * from draw_amounts limit 100;
 -- STEP 7: join the draw_amounts table and the principal_AR table to get the draw amount as a percentage of the unused utilization for each LOC
  select

  da.loan_id
  ,da.draw1_amount/(da.credit_limit-dpa.total_principal_ar_until_draw1) as draw1_perc_of_cl_left
  ,da.draw2_amount/(da.credit_limit-dpa.total_principal_ar_until_draw2) as draw2_perc_of_cl_left
  ,da.draw3_amount/(da.credit_limit-dpa.total_principal_ar_until_draw3) as draw3_perc_of_cl_left
  ,da.draw4_amount/(da.credit_limit-dpa.total_principal_ar_until_draw4) as draw4_perc_of_cl_left
  ,da.draw5_amount/(da.credit_limit-dpa.total_principal_ar_until_draw5) as draw5_perc_of_cl_left
  ,da.draw6_amount/(da.credit_limit-dpa.total_principal_ar_until_draw6) as draw6_perc_of_cl_left

  from draw_amounts da

  inner join draw_principal_ar dpa
  on dpa.loan_id = da.loan_id


  ;




-- STEP 7: create table for survival regression

select
  ad.loan_id
  ,ih.installment_due_date default_date
  ,ih3.installment_due_date maturity_date
  ,ih.current_default
  ,hr.repayment_frequency
  ,dr1.funding_date funding1
  ,dr2.funding_date funding2
  ,dr3.funding_date funding3
  ,dr4.funding_date funding4
  ,dr5.funding_date funding5
  ,dr6.funding_date funding6
  ,case when (dr1.funding_date + interval '1 month') < current_date then
    sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '1 month') then pp.amount else 0 end)
    -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '1 month') then pp.amount else 0 end)
    else NULL end
  as principal_after_1
  ,case when (dr1.funding_date + interval '2 month') < current_date then
  sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '2 month') then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '2 month') then pp.amount else 0 end)
    else NULL end
  as principal_after_2
  ,case when (dr1.funding_date + interval '3 month') < current_date then
  sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '3 month') then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '3 month') then pp.amount else 0 end)
  else NULL end
  as principal_after_3
  ,case when (dr1.funding_date + interval '4 month') < current_date then
  sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '4 month') then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '4 month') then pp.amount else 0 end)
  else NULL end
  as principal_after_4
  ,case when (dr1.funding_date + interval '5 month') < current_date then
  sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '5 month') then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '5 month') then pp.amount else 0 end)
  else NULL end
  as principal_after_5
  ,case when (dr1.funding_date + interval '6 month') < current_date then
  sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '6 month') then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '6 month') then pp.amount else 0 end)
  else NULL end
  as principal_after_6

  ,case when (dr1.funding_date + interval '7 month') < current_date then
    sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '7 month') then pp.amount else 0 end)
    -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '7 month') then pp.amount else 0 end)
    else NULL end
  as principal_after_7
  ,case when (dr1.funding_date + interval '8 month') < current_date then
  sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '8 month') then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '8 month') then pp.amount else 0 end)
    else NULL end
  as principal_after_8
  ,case when (dr1.funding_date + interval '9 month') < current_date then
  sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '9 month') then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '9 month') then pp.amount else 0 end)
  else NULL end
  as principal_after_9
  ,case when (dr1.funding_date + interval '10 month') < current_date then
  sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '10 month') then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '10 month') then pp.amount else 0 end)
  else NULL end
  as principal_after_10
  ,case when (dr1.funding_date + interval '11 month') < current_date then
  sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '11 month') then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '11 month') then pp.amount else 0 end)
  else NULL end
  as principal_after_11
  ,case when (dr1.funding_date + interval '12 month') < current_date then
  sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '12 month') then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '12 month') then pp.amount else 0 end)
  else NULL end
  as principal_after_12

  ,case when (dr1.funding_date + interval '13 month') < current_date then
    sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '13 month') then pp.amount else 0 end)
    -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '13 month') then pp.amount else 0 end)
    else NULL end
  as principal_after_13
  ,case when (dr1.funding_date + interval '14 month') < current_date then
  sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '14 month') then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '14 month') then pp.amount else 0 end)
    else NULL end
  as principal_after_14
  ,case when (dr1.funding_date + interval '15 month') < current_date then
  sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '15 month') then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '15 month') then pp.amount else 0 end)
  else NULL end
  as principal_after_15
  ,case when (dr1.funding_date + interval '16 month') < current_date then
  sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '16 month') then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '16 month') then pp.amount else 0 end)
  else NULL end
  as principal_after_16
  ,case when (dr1.funding_date + interval '17 month') < current_date then
  sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '17 month') then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '17 month') then pp.amount else 0 end)
  else NULL end
  as principal_after_17
  ,case when (dr1.funding_date + interval '18 month') < current_date then
  sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '18 month') then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '18 month') then pp.amount else 0 end)
  else NULL end
  as principal_after_18

  ,case when (dr1.funding_date + interval '19 month') < current_date then
    sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '19 month') then pp.amount else 0 end)
    -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '19 month') then pp.amount else 0 end)
    else NULL end
  as principal_after_19
  ,case when (dr1.funding_date + interval '20 month') < current_date then
  sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '20 month') then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '20 month') then pp.amount else 0 end)
    else NULL end
  as principal_after_20
  ,case when (dr1.funding_date + interval '21 month') < current_date then
  sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '21 month') then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '21 month') then pp.amount else 0 end)
  else NULL end
  as principal_after_21
  ,case when (dr1.funding_date + interval '22 month') < current_date then
  sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '22 month') then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '22 month') then pp.amount else 0 end)
  else NULL end
  as principal_after_22
  ,case when (dr1.funding_date + interval '23 month') < current_date then
  sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '23 month') then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '23 month') then pp.amount else 0 end)
  else NULL end
  as principal_after_23
  ,case when (dr1.funding_date + interval '24 month') < current_date then
  sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '24 month') then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '24 month') then pp.amount else 0 end)
  else NULL end
  as principal_after_24
  ,case when (dr1.funding_date + interval '25 month') < current_date then
    sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '25 month') then pp.amount else 0 end)
    -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '25 month') then pp.amount else 0 end)
    else NULL end
  as principal_after_25
  ,case when (dr1.funding_date + interval '26 month') < current_date then
  sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '26 month') then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '26 month') then pp.amount else 0 end)
    else NULL end
  as principal_after_26
  ,case when (dr1.funding_date + interval '27 month') < current_date then
  sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '27 month') then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '27 month') then pp.amount else 0 end)
  else NULL end
  as principal_after_27
  ,case when (dr1.funding_date + interval '28 month') < current_date then
  sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '28 month') then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '28 month') then pp.amount else 0 end)
  else NULL end
  as principal_after_28
  ,case when (dr1.funding_date + interval '29 month') < current_date then
  sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '29 month') then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '29 month') then pp.amount else 0 end)
  else NULL end
  as principal_after_29
  ,case when (dr1.funding_date + interval '30 month') < current_date then
  sum(case when pp.debit_account_type = 'AR' and pp.debit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '30 month') then pp.amount else 0 end)
  -sum(case when pp.credit_account_type = 'AR' and pp.credit_account_cd like '%principal%' and pp.accounting_date < (dr1.funding_date + interval '30 month') then pp.amount else 0 end)
  else NULL end
  as principal_after_30

from all_draws ad
  left join nbox_portfolio_portfolio.draw_requests dr1
  on dr1.draw_request_id = ad.draw1
  left join nbox_portfolio_portfolio.draw_requests dr2
  on dr2.draw_request_id = ad.draw2
  left join nbox_portfolio_portfolio.draw_requests dr3
  on dr3.draw_request_id = ad.draw3
  left join nbox_portfolio_portfolio.draw_requests dr4
  on dr4.draw_request_id = ad.draw4
  left join nbox_portfolio_portfolio.draw_requests dr5
  on dr5.draw_request_id = ad.draw5
  left join nbox_portfolio_portfolio.draw_requests dr6
  on dr6.draw_request_id = ad.draw6
inner join accounting_table pp on pp.loan_id = ad.loan_id
left join hd_operations.headway_reporting hr on hr.loan_id = ad.loan_id
LEFT JOIN hd_reporting.installments_headway ih on ih.installment_id =
         (SELECT min(ih2.installment_id)
          FROM hd_reporting.installments_headway ih2
          WHERE ih2.loan_id = ad.loan_id
            and ih2.lagged_current_default = TRUE)
LEFT JOIN hd_reporting.installments_headway ih3 on ih3.installment_id =
         (SELECT max(ih4.installment_id)
         FROM hd_reporting.installments_headway ih4
         WHERE ih4.loan_id = ad.loan_id)
GROUP BY  1,2,3,4,5,6,7,8,9,10,11
;





