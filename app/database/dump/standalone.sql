-- phpMyAdmin SQL Dump
-- version 4.1.12
-- http://www.phpmyadmin.net
--
-- Host: 127.0.0.1
-- Generation Time: May 20, 2014 at 09:13 PM
-- Server version: 5.6.16
-- PHP Version: 5.5.11

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;

--
-- Database: `gurudev`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`testuser1`@`%` PROCEDURE `ha_confirm_hot_alert_read`( 
          IN  p_haid        integer unsigned, 
          IN  p_uid         integer unsigned 
         )
stored_procedure:
begin
   declare v_msg              varchar(255);
   declare v_rows, v_err      int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;   
   set @sp_return_stat = 0;
   
   insert hot_alert_read_monitor( haid, uid, read_date ) 
      select p_haid, p_uid, now()
      from   ha_read_monitor_initial
      where  haid       = p_haid 
      and    reader_uid = p_uid 
      and    read_date is null;
   insert hot_alert_read_monitor( haid, hanid, uid, read_date ) 
      select p_haid, hanid, p_uid, now()
      from   ha_read_monitor_note
      where  haid       = p_haid 
      and    reader_uid = p_uid 
      and    read_date is null;
 
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `ha_extract_to_email`( 
          IN  p_haid                 int unsigned,
          IN  p_action               char(10),    -- use "ONE"   (future options for inactivity etc)
          IN  p_email_type           varchar(255) -- use "ha"    (future options "initial_ha" | "no_activity_ha" )
         )
stored_procedure:
begin
   -- cursor items:
   declare v_orgid            int unsigned;
   declare v_rid              int unsigned;
   declare v_ab_emid          int unsigned;
   declare v_ab_eid           int unsigned;
   declare v_lid              int unsigned;
   declare v_link             varchar(255);
   declare v_no_data          tinyint;
   
   declare v_msg              varchar(255);
   declare v_rows, v_err      int default 0;
   declare curse1 cursor for
      select rid, orgid, ab_emid, ab_eid
      from   t_ha_ids
      where  bld_link = 1;
   
   declare CONTINUE handler for NOT FOUND
   begin
      set v_no_data = TRUE;
   end;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;   
   set @sp_return_stat = 0;
   -- to identify  ha(s) and if result link ok
   CREATE TEMPORARY TABLE IF NOT EXISTS t_ha_ids(
      haid        integer unsigned not null,
      orgid       integer unsigned not null,
      dflt_lngid  integer unsigned,
      rid         integer unsigned not null,
      ab_emid     int unsigned,
      ab_eid      int unsigned,   
      bld_link    tinyint unsigned not null,
      link        varchar(255) null
      ) ENGINE=MEMORY;
   truncate table t_ha_ids;
   
   case p_action
   when "ONE" then --
      insert t_ha_ids ( haid, orgid, dflt_lngid, rid, ab_emid, ab_eid, bld_link, link )
         -- Note: Would only be once per rid if it has multiple alerts
         select H.haid, H.orgid, G.lngid, H.rid, T.ab_emid, T.ab_eid,
                1 - ifnull(sign(L.lid),0) as bld_link, L.link
         from       hot_alert H               
         inner join rids R
            on H.rid = R.rid
         inner join ab_email_recipients T
            on R.ab_rcpid = T.ab_rcpid
         left outer join links L
            on  T.ab_emid   = L.ab_emid
            and T.ab_eid    = L.ab_eid
            and L.link_type = "irt"
            and L.source    = "L"
         left outer join org_langs  G
            on  H.orgid        = G.orgid
            and use_as_default = 1
         where  haid = p_haid;
         set v_rows  = ROW_COUNT();
         if v_rows != 1 then
            set @sp_return_stat = 1, v_msg = concat( 'ha_extract_to_email: unknown hot alert haid= ', p_haid);
            SIGNAL SQLSTATE '01000'
            SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
            leave stored_procedure; 
         end if;
   else
      set @sp_return_stat = 1, v_msg = concat( 'ha_extract_to_email: unknown action = ', p_action);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end case;
   -- Fix up where missing irt links, better if sorted during response store!
   if exists ( select * from t_ha_ids where bld_link = 1 ) then
      open curse1;
   
      set v_no_data = 0;
      curse1_loop: 
      loop 
         fetch curse1 into v_rid, v_orgid, v_ab_emid, v_ab_eid;
         if v_no_data then leave curse1_loop; end if;     
         
         call inv_build_single_link (
           v_orgid,   -- p_orgid 
           "L",       -- p_source     -- LOCAL
           "irt",     -- p_link_type -- Individual Result
           null,      -- p_suid      -- latest or should we derive from rid  ?
           null,      -- p_lngid     -- not appplicable
           v_ab_emid, -- p_ab_emid 
           v_ab_eid,  -- p_ab_eid 
           v_lid,     -- p_lid  out
           v_link     -- p_link out
           ); 
   
         -- mysql has no update via cursor position
         update t_ha_ids
         set    link = v_link
         where  rid      = v_rid
         and    bld_link = 1;
      end loop;
      close curse1;
   end if;
 -- @sp_debug = 1;
   -- identify default language in case language template missing?
   -- Three main result sets
   -- ---------------------------------------------------------------------------
   -- (a) Hot Alert Email Header & Hot Alert rid header combined (all languages)
   -- ---------------------------------------------------------------------------    
   select -- Recipient index keys
          H.haid,
          T.orgid,
          T.etid,
          T.lngid,
          -- Template details
          T.name as tmplt_type,
          A.name as alert_type,
          L.name as language, 
          case T.lngid when I.dflt_lngid then 1 else 0 end as dflt_lang,
          T.html_email, T.envelope_sender_name, T.envelope_sender_email,
          T.subject, T.body,
          -- Result details
          H.rid,
          I.link  as rid_link,
          R.email as guest_email,
          R.name  as guest_name,
          R.last_update date_completed,
          S.name as ha_status,
          ifnull(H.date_last_note_added, H.create_date) as ha_date_last_edit
   from       t_ha_ids I
   inner join hot_alert H
      on  I.haid = H.haid
   inner join hot_alert_type A
      on  H.htid   = A.htid -- must exist in hot alerts
   inner join  ha_note_statuses S
      on  H.status = S.hnsid
   inner join email_template T
      on  H.orgid  = T.orgid
      and H.htid   = T.htid
      and T.name   = p_email_type
   inner join language L
      on  T.lngid  = L.lngid
   inner join rids R
      on  H.rid    = R.rid;
   -- ---------------------------------------------------------------------------
   -- (b) Hot Alert Notes to attach to each header (a)
   -- ---------------------------------------------------------------------------
   select N.haid, N.hanid, N.date, U.first_name, U.last_name, U.email, N.comment
   from   t_ha_ids  I,
          hot_alert_note N,
          users U 
   where  I.haid = N.haid
   and    N.uid  = U.uid 
   order by N.date desc;
   -- ---------------------------------------------------------------------------
   -- (c) Hot Alert recipients to email out
   -- ---------------------------------------------------------------------------
   -- Tie with (haid, etid)
   select H.haid, H.orgid, T.etid, -- etid template could be null could not send, or perhaps switch to default ?
          U.harid, U.uid,  L.name as language, U.email, U.first_name, U.last_name 
   from   t_ha_ids  I
   inner join ha_user_to_email U
      on I.haid   = U.haid
   inner join language L
      on  U.lngid  = L.lngid  -- Mainly for debug clarity
   inner join hot_alert H
      on U.haid    = H.haid
   left outer join email_template T
      on  H.orgid  = T.orgid
      and H.htid   = T.htid
      and U.lngid  = T.lngid
      and T.name   = p_email_type
   where  U.active = 1;
   drop temporary table t_ha_ids;
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `ha_get_unattended_alert_users`( 
         )
stored_procedure:
begin
   declare v_rpt_org_type     char(1);
   declare v_msg                   varchar(255);
   declare v_rows, v_err      int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;   
   set @sp_return_stat = 0;
   
   CREATE TABLE t_hot_alerts_to_notify ENGINE=MEMORY
      select H.orgid, H.haid, H.htid,
             H.create_date, H.date_last_note_added, last_no_action_msg_date,
             date_sub( now(), INTERVAL notify_no_action_days DAY ) as no_acion_date
      from   hot_alert     H,
             organisation  O
      where  H.orgid  = O.orgid
      and    O.active = 1
      and    H.open   = 1
      and    ifnull(H.date_last_note_added,    H.create_date ) < date_sub( now(), INTERVAL notify_no_action_days DAY )
      and    ifnull(H.last_no_action_msg_date, H.create_date ) < date_sub( now(), INTERVAL notify_no_action_days DAY )
   ;
   if @sp_debug = 1 then
      select * from t_hot_alerts_to_notify;
   end if;
   select  H.orgid, H.haid, E.uid, E.email, E.first_name, E.last_name,  E.active
   from    t_hot_alerts_to_notify H,
           ha_user_to_email       E 
   where   H.haid = E.haid
   and     E.active = 1
   order by 1, 2;   
   drop table t_hot_alerts_to_notify;
end$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `ha_note_status_edit`( 
          IN  p_uid                  int unsigned,
          IN  p_action               char(1),      -- (A)dd, (E)dit, (R)emove
           -- use null(s) below if not relevant/no change
          IN  p_hnsid                int unsigned,
          IN  p_name                 varchar(255),
          IN  p_is_initial_state     tinyint
         )
stored_procedure:
begin
   declare v_orgid            int unsigned;
   declare v_msg              varchar(255);
   declare v_rows, v_err      int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;   
   set @sp_return_stat = 0;
   select orgid into v_orgid
   from   users
   where  uid = p_uid;
   set v_rows = ROW_COUNT();
   if v_rows != 1 then
      set @sp_return_stat = 1, v_msg = concat( 'ha_note_status_edit: unknown uid ', p_uid);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if; 
   case p_action
   when "A" then -- Add
      -- Allow for logically removed state
      insert ha_note_statuses (orgid, name, active, is_initial_state) 
         select v_orgid, p_name , 1, 0
         from   dual
         where not exists (select hnsid from ha_note_statuses where orgid = v_orgid and name = p_name);
      set v_rows = ROW_COUNT(), p_hnsid = LAST_INSERT_ID();
      if v_rows = 0 then 
         -- reinstate old if inactive state
         select hnsid into p_hnsid -- also need if initial state -> 1
         from   ha_note_statuses
         where  orgid  = v_orgid
         and    name   = p_name;
         update ha_note_statuses
         set    active = 1
         where  hnsid  = p_hnsid
         and    active = 0;
      end if;
   when "E" then -- Edit
     update ha_note_statuses 
     set    name   = p_name 
     where  hnsid  = p_hnsid
     and    active = 1;
   when "R" then -- Remove logically leaving integrity ok on old ha
     update ha_note_statuses 
     set    active = 0 
     where  hnsid  = p_hnsid
     and    is_initial_state = 0; -- ignore remove if initial state, no error given at sp level
   else
      set @sp_return_stat = 1, v_msg = concat( 'ha_note_status_edit: unknown action = ', p_action);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end case;
   -- single transaction if initial_state must switch
   if p_is_initial_state = 1 and p_action in ("A", "E" ) and p_hnsid > 0 then
      START TRANSACTION;
      
      update ha_note_statuses
      set    is_initial_state = 0
      where  orgid = v_orgid
      and    is_initial_state = 1;
      
      update ha_note_statuses
      set    is_initial_state = 1
      where  hnsid  = p_hnsid
      and    active = 1;
      set v_rows = ROW_COUNT();
      if v_rows = 1 then
         COMMIT;
      else
         ROLLBACK;
      end if;
   end if;
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `ha_note_user_add`( 
          IN  p_haid                 int unsigned,
          -- recipient: Either p_rcp_uid is null and the rest have values or  p_rcp_uid only is set
          INOUT p_rcp_uid            int unsigned,
          IN    p_rcp_email          varchar(255),
          IN    p_rcp_first_name     varchar(100), 
          IN    p_rcp_last_name      varchar(100),
          IN    p_rcp_password       varchar(255)  -- random chars
         )
stored_procedure:
begin
   declare v_new_username     varchar(40);
   declare v_orgid            int unsigned;
   declare v_msg              varchar(255);
   declare v_rows, v_err      int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;   
   set @sp_return_stat = 0;
   select orgid into v_orgid
   from   hot_alert
   where  haid = p_haid;
   set v_rows = ROW_COUNT();
   if v_rows != 1 then
      set @sp_return_stat = 1, v_msg = concat( 'ha_note_user_add: unknown hot alert haid= ', p_haid);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;
   -- Ensure a new user does not duplicate existing user!
   if p_rcp_uid is null then
      select uid into p_rcp_uid
      from   users
      where  email = p_rcp_email;
   end if;
   if p_rcp_uid is null then -- Add ha user 
      set v_new_username = concat(p_rcp_first_name,p_rcp_last_name );
      call usr_build (
         p_rcp_uid,        -- p_uid
         'I',              -- p_action INSERT
         v_orgid,          -- p_orgid 
         null,             -- p_lngid  - CHANGED TO allow null & lookup
         1,                -- p_active
         'ha',             -- p_contact_type  - not 'Main' as java did 
         v_new_username,   -- p_username
         p_rcp_password,   -- p_password  random number for new hot alert user
         p_rcp_first_name, -- p_first_name
         p_rcp_last_name,  -- p_last_name
         null,             -- p_position
         p_rcp_email,      -- p_email
         null,             -- p_tel
         null,             -- p_fax
         null,             -- p_mobile,
         "alert_user"      -- p_role_name
           );
   end if;
   -- add extra note user provided not already in
   insert hot_alert_recipient (haid, uid) 
      select p_haid, p_rcp_uid
      from dual 
      where not exists( select uid from ha_user_to_email where haid = p_haid and uid = p_rcp_uid );
   -- set v_rows = ROW_COUNT();
   -- select v_rows rows_added; select "ASSOC", haid, uid from hot_alert_recipient where haid = p_haid;
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `ha_show_list`( 
          IN  p_orgid       integer unsigned, -- always supply
          IN  p_top_bot     tinyint,          -- for G/A, else null
          IN  p_open        tinyint unsigned,
          IN  p_status      integer unsigned,
          IN  p_uid         integer unsigned  -- user when restricting to list
         )
stored_procedure:
begin
   declare v_rpt_org_type     char(1);
   declare v_msg                   varchar(255);
   declare v_rows, v_err      int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;   
   set @sp_return_stat = 0;
   -- need to ability to assess Top 5 properties etc, what is the date range
   CREATE TEMPORARY TABLE IF NOT EXISTS t_ha_orgs( 
      orgid    integer unsigned not null,
      num_ha   integer not null
      ) ENGINE=MEMORY;
   truncate table t_ha_orgs;
      
   -- Determine what is required from org type
   select O.type into v_rpt_org_type
   from   organisation O
   where  O.orgid = p_orgid;
      
   set v_rows = ROW_COUNT();
   if v_rows != 1 then
      set @sp_return_stat = 1, v_msg = concat( 'ha_show_list: unknown orgid ', p_orgid);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if; 
   if v_rpt_org_type = "S" then
      insert t_ha_orgs( orgid, num_ha ) values ( p_orgid, 0 );   
 
   else 
      if ( v_rpt_org_type = "G" or v_rpt_org_type = "A" ) then
         if p_top_bot < 0 then
            set p_top_bot = -p_top_bot;
            
            insert t_ha_orgs( orgid, num_ha )
               select ha.orgid , count(*)
               from   org_relation r,
                      hot_alert    ha,
                      rids         d        
               where  r.p_orgid  = p_orgid
               and    c_type     = "S"
               and    p_active   = 1
               and    c_active   = 1
               and    r.c_orgid  = ha.orgid
               and    ha.open    = p_open
               and    ha.status  = ifnull( p_status, ha.status )
               and    ha.rid     = d.rid
               and    d.status  = 1
               group by ha.orgid 
               order by 2 asc limit p_top_bot;
         elseif p_top_bot < 0 then
            insert t_ha_orgs( orgid, num_ha )
               select ha.orgid , count(*)
               from   org_relation r,
                      hot_alert    ha,
                      rids         d        
               where  r.p_orgid  = p_orgid
               and    c_type     = "S"
               and    p_active   = 1
               and    c_active   = 1
               and    r.c_orgid  = ha.orgid
               and    ha.open    = p_open
               and    ha.status  = ifnull( p_status, ha.status )
               and    ha.rid     = d.rid
               and    d.status  = 1
               group by ha.orgid 
               order by 2 desc limit p_top_bot;
         else
            insert t_ha_orgs( orgid, num_ha )
               select ha.orgid , count(*)
               from   org_relation r,
                      hot_alert    ha,
                      rids         d        
               where  r.p_orgid  = p_orgid
               and    c_type     = "S"
               and    p_active   = 1
               and    c_active   = 1
               and    r.c_orgid  = ha.orgid
               and    ha.open    = p_open
               and    ha.status  = ifnull( p_status, ha.status )
               and    ha.rid     = d.rid
               and    d.status  = 1
               group by ha.orgid ;         
         end if;
      end if;
   end if;
/*         
          ( select max ( n.date) 
                    from hot_alert_note n
                    where ha.haid = n.haid )
*/
   if p_uid is null then 
      select ha.haid, r.email, r.name, ha.status,
             ifnull( ha.date_last_note_added, ha.create_date ) as last_activity,
             r.rid, ha.open,
             r.last_update,
             rslt_check_rtype_answer_exists(
              r.rid, 
              "ITM_LOW_SATISFACTION_CONTACT", 
              "ANS_DECIDE_NO", null ) as prefers_no_contact
      from   t_ha_orgs o,
             hot_alert ha,
             rids      r,
             ha_note_statuses s          
      where  o.orgid   = ha.orgid 
      and    ha.open   = p_open
      and    ha.status = ifnull( p_status, ha.status )
      and    ha.rid    = r.rid
      and    r.status  = 1
      and    ha.status = s.hnsid;
   else
      -- User specific visibility to hot alerts
      select ha.haid, r.email, r.name, ha.status,
             ifnull( ha.date_last_note_added, ha.create_date ) as last_activity,
             r.rid, ha.open,
             r.last_update,
             rslt_check_rtype_answer_exists(
              r.rid, 
              "ITM_LOW_SATISFACTION_CONTACT", 
              "ANS_DECIDE_NO", null ) as prefers_no_contact
      from   t_ha_orgs o,
             hot_alert ha,
             rids      r,
             ha_note_statuses s,
             ha_user_to_email u
      where  o.orgid   = ha.orgid 
      and    ha.open   = p_open
      and    ha.status = ifnull( p_status, ha.status )
      and    ha.rid    = r.rid
      and    r.status  = 1
      and    ha.status = s.hnsid
      and    ha.haid   = u.haid
      and    u.uid     = p_uid;
      
   end if;
end$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `ha_show_list_php`( 
          IN  p_orgid    integer unsigned, -- always supply
          IN  p_top_bot  tinyint,          -- +/- num for Group/Association,
                                           -- else use null
          IN  p_open     tinyint unsigned, -- filtering open/closed
          IN  p_status   integer unsigned, -- null for all or specific state id
          IN  p_uid      integer unsigned, -- use null unless specific user to email
          IN  p_haid     integer unsigned  -- use null or haid if for single read
         )
stored_procedure:
begin
   declare v_rpt_org_type     char(1);
   declare v_msg                   varchar(255);
   declare v_rows, v_err      int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;   
   set @sp_return_stat = 0;
   -- need to ability to assess Top 5 properties etc, what is the date range
   CREATE TEMPORARY TABLE IF NOT EXISTS t_ha_orgs( 
      orgid    integer unsigned not null,
      num_ha   integer not null
      ) ENGINE=MEMORY;
   truncate table t_ha_orgs;
      
   -- Determine what is required from org type
   select O.type into v_rpt_org_type
   from   organisation O
   where  O.orgid = p_orgid;
      
   set v_rows = ROW_COUNT();
   if v_rows != 1 then
      set @sp_return_stat = 1, v_msg = concat( 'ha_show_list_php: unknown orgid ', p_orgid);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if; 
   if v_rpt_org_type = "S" then
      insert t_ha_orgs( orgid, num_ha ) values ( p_orgid, 0 );   
 
   else 
      if ( v_rpt_org_type = "G" or v_rpt_org_type = "A" ) then
         if p_top_bot < 0 then
            set p_top_bot = -p_top_bot;
            
            insert t_ha_orgs( orgid, num_ha )
               select ha.orgid , count(*)
               from   org_relation r,
                      hot_alert    ha,
                      rids         d        
               where  r.p_orgid  = p_orgid
               and    c_type     = "S"
               and    p_active   = 1
               and    c_active   = 1
               and    r.c_orgid  = ha.orgid
               and    ha.open    = p_open
               and    ha.status  = ifnull( p_status, ha.status )
               and    ha.rid     = d.rid
               and    d.status  = 1
               group by ha.orgid 
               order by 2 asc limit p_top_bot;
         elseif p_top_bot < 0 then
            insert t_ha_orgs( orgid, num_ha )
               select ha.orgid , count(*)
               from   org_relation r,
                      hot_alert    ha,
                      rids         d        
               where  r.p_orgid  = p_orgid
               and    c_type     = "S"
               and    p_active   = 1
               and    c_active   = 1
               and    r.c_orgid  = ha.orgid
               and    ha.open    = p_open
               and    ha.status  = ifnull( p_status, ha.status )
               and    ha.rid     = d.rid
               and    d.status  = 1
               group by ha.orgid 
               order by 2 desc limit p_top_bot;
         else
            insert t_ha_orgs( orgid, num_ha )
               select ha.orgid , count(*)
               from   org_relation r,
                      hot_alert    ha,
                      rids         d        
               where  r.p_orgid  = p_orgid
               and    c_type     = "S"
               and    p_active   = 1
               and    c_active   = 1
               and    r.c_orgid  = ha.orgid
               and    ha.open    = p_open
               and    ha.status  = ifnull( p_status, ha.status )
               and    ha.rid     = d.rid
               and    d.status  = 1
               group by ha.orgid ;         
         end if;
      end if;
   end if;
/*         
          ( select max ( n.date) 
                    from hot_alert_note n
                    where ha.haid = n.haid )
*/
   if p_haid is not null then -- Support read of single ha by it's id
      select ha.haid, r.email, r.name, ha.status, s.name as latest_status,
             ifnull( ha.date_last_note_added, ha.create_date ) as last_activity,
             ha.open,
             r.rid, r.qnid, r.last_update,
             rslt_check_rtype_answer_exists( r.rid,
                "ITM_LOW_SATISFACTION_CONTACT", 
                "ANS_DECIDE_NO", null ) as prefers_no_contact
      from   hot_alert ha,
             rids      r,
             ha_note_statuses s          
      where  ha.haid   = p_haid
      and    ha.rid    = r.rid
      and    ha.status = s.hnsid; 
      
      select n.hanid, n.date, n.comment, u.first_name, u.last_name, u.email 
      from hot_alert_note n,
           users u 
      where n.haid = p_haid
      and   n.uid = u.uid 
      order by n.date desc;
      -- To read the list of recipients
      select type, orgid, haid, harid, uid, email, first_name, last_name, active 
      from   ha_user_to_email
      where  haid =  p_haid;
   elseif p_uid is null then 
      -- Not User specific visibility to hot alerts
      select ha.haid, r.email, r.name, ha.status, s.name as latest_status,
             ifnull( ha.date_last_note_added, ha.create_date ) as last_activity,
             ha.open,
             r.rid, r.qnid, r.last_update,
             rslt_check_rtype_answer_exists( r.rid,
                "ITM_LOW_SATISFACTION_CONTACT", 
                "ANS_DECIDE_NO", null ) as prefers_no_contact
      from   t_ha_orgs o,
             hot_alert ha,
             rids      r,
             ha_note_statuses s          
      where  o.orgid   = ha.orgid 
      and    ha.open   = p_open
      and    ha.status = ifnull( p_status, ha.status )
      and    ha.rid    = r.rid
      and    r.status  = 1
      and    ha.status = s.hnsid;
   else
      -- User specific visibility to hot alerts
      select ha.haid, r.email, r.name, ha.status, s.name as latest_status,
             ifnull( ha.date_last_note_added, ha.create_date ) as last_activity,
             ha.open,
             r.rid, r.qnid, r.last_update,
             rslt_check_rtype_answer_exists( r.rid,
                "ITM_LOW_SATISFACTION_CONTACT", 
                "ANS_DECIDE_NO", null ) as prefers_no_contact
      from   t_ha_orgs o,
             hot_alert ha,
             rids      r,
             ha_note_statuses s,
             ha_user_to_email u
      where  o.orgid   = ha.orgid 
      and    ha.open   = p_open
      and    ha.status = ifnull( p_status, ha.status )
      and    ha.rid    = r.rid
      and    r.status  = 1
      and    ha.status = s.hnsid
      and    ha.haid   = u.haid
      and    u.uid     = p_uid;
      
   end if;
   
   drop temporary table t_ha_orgs;
end$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `inv_build_distribution`( 
          IN  p_orgid          integer unsigned,
          IN  p_release_date   datetime, 
          IN  p_checkout_date  datetime, 
          IN  p_remote_feed    tinyint unsigned,
          OUT p_ab_emid        integer unsigned
          
         )
stored_procedure:
begin
   declare v_reminder_gap_days            int unsigned;
   declare v_max_invitation_period_months int unsigned;
   declare v_days_between_reminders       int unsigned;
   declare v_no_reminders                 int unsigned;
   declare v_send_invitation_delay_day    int unsigned;
   declare v_suid, v_qnid                 int unsigned;
   declare v_max_invitation_period_date   datetime; 
   declare v_rows, v_err   int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      drop temporary table if exists t_new_members;
      RESIGNAL;
   end;  
   set @sp_return_stat = 0;
   
   select 
          send_invitation_delay_day,   max_invitation_period_months, 
          no_of_reminders,             reminder_gap_days
          into 
          v_send_invitation_delay_day, v_max_invitation_period_months,
          v_no_reminders,              v_reminder_gap_days 
   from   organisation
   where  orgid = p_orgid;
   SET v_rows = ROW_COUNT();
   
   if v_rows != 1 then
      set @sp_return_stat = 1;
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = 'inv_build_distribution: org not found', MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;  
   
   select suid, qnid into v_suid, v_qnid
   from   survey_used
   where  orgid = p_orgid
   and    active = 1
   and    date_end is null;
 
   SET v_rows = ROW_COUNT();
   
   if v_rows != 1 then
      set @sp_return_stat = 1;
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = 'inv_build_distribution: need 1 active survey', MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if; 
   
      
   SET v_max_invitation_period_date = DATE_ADD( now(), INTERVAL - v_max_invitation_period_months MONTH ); 
   
   
   SET p_checkout_date              = DATE_ADD( date( p_checkout_date ), INTERVAL TIME(now()) HOUR_SECOND ) ;
   
   
   
   if DATE_ADD( p_checkout_date, INTERVAL v_send_invitation_delay_day DAY ) < now() then
      select p_checkout_date  = 
         DATE_ADD( now(), INTERVAL - v_send_invitation_delay_day DAY );
   end if;
   insert ab_emails( orgid, suid, create_date, run_date, status, num_of_reminders, 
                     days_between_reminders, prepare_auto_remind, skip_notify )
   values ( p_orgid, v_suid, now(), 
            DATE_ADD( p_checkout_date, INTERVAL v_send_invitation_delay_day DAY ),
            "PENDING", v_no_reminders, v_reminder_gap_days, 1, 1 );
 
   set p_ab_emid = LAST_INSERT_ID();
   
   drop temporary table if exists t_new_members;
   
   CREATE TEMPORARY TABLE t_new_members
      ( ab_eid  integer unsigned, email varchar(60) ) ENGINE=MEMORY;
   
   insert t_new_members (ab_eid, email)
      select ab_eid, email
      from   ab_list_members
      where  orgid = p_orgid
      and    release_date = p_release_date
      and    email not in (select email from blocked_emails where orgid = p_orgid );
   delete M 
   from   t_new_members       M,
          ab_email_recipients R,
          ab_emails           E
   where v_max_invitation_period_months > 0
   and   E.orgid       = p_orgid
   and   E.create_date > v_max_invitation_period_date
   and   E.ab_emid     = R.ab_emid
   and   R.ab_eid      = M.ab_eid
   and   M.email not in ( select email from no_de_dupe_emails where orgid = p_orgid );
   insert ab_email_recipients( ab_emid, ab_eid, email, status, remind)
      select p_ab_emid,
             ab_eid,
             email,
             'PENDING' as status,
             0         as remind
      from   t_new_members;
   SET v_rows = ROW_COUNT();
   
   if v_rows = 0 then 
      update ab_emails 
      set    status = "NOT SENT"
      where ab_emid = p_ab_emid;
      drop temporary table if exists t_new_members;
      leave stored_procedure; 
   end if;
   call inv_build_recipient_links(
          p_ab_emid,   
          "PENDING" ); 
          
   if @sp_debug = 1 then
      select * from ab_emails           where ab_emid= p_ab_emid;
      select * from ab_email_recipients where ab_emid= p_ab_emid;
   end if;
   
   
  insert rids( orig_rid, qnid, orgid, date_started, last_update, status, ab_rcpid, email, name, remote_feed )
      select null as orig_rid, v_qnid, p_orgid, 
             now() as date_started, now() as last_update, 0 as status, 
             R.ab_rcpid, R.email, M.invite_name as name,
             p_remote_feed
      from  ab_email_recipients R,
            ab_list_members M
      where R.ab_emid  = p_ab_emid
      and   M.orgid    = p_orgid
      and   R.ab_eid   = M.ab_eid;
   drop temporary table if exists t_new_members;
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `inv_build_recipient_links`( 
          IN  p_ab_emid          integer unsigned,
          IN  p_status           varchar(15)
         )
stored_procedure:
begin
   declare v_suid, v_orgid integer unsigned;
   declare v_string_set    char(64);
   declare v_num_rebuild   int;
   declare v_t1            datetime;
   declare v_retries       int;
   declare v_rows, v_err   int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      drop temporary table if exists t_new_links;
      drop temporary table if exists t_rework_links;
      RESIGNAL;
   end;    
   set @sp_return_stat = 0;
   
   drop temporary table if exists t_new_links;
   drop temporary table if exists t_rework_links;
   
   CREATE TEMPORARY TABLE t_new_links
      ( ab_eid  integer unsigned,
        lnk     varchar(20) ) ENGINE=MEMORY;
   CREATE TEMPORARY TABLE t_rework_links
      ( ab_eid          integer unsigned,
        lnk             varchar(20),
        generated_dupe  int ) ENGINE=MEMORY;
        
   set v_string_set  = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.-",
       v_num_rebuild = 1,
       v_retries     = 0;
   select suid, orgid into v_suid, v_orgid
   from   ab_emails
   where  ab_emid = p_ab_emid; 
        
   insert t_new_links ( ab_eid, lnk )
      select ab_eid,
             concat(
          substring( v_string_set, floor( 1+ 64 * rand() ), 1), 
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 62 * rand() ), 1) ) as lnk 
      from  ab_email_recipients
      where ab_emid = p_ab_emid
      and   status  = p_status;
      
   SET v_rows = ROW_COUNT();
   
   delete N
   from   links       L,
          t_new_links N
   where  L.ab_emid = p_ab_emid
   and    L.ab_eid  = N.ab_eid;
 
   SET v_rows = v_rows - ROW_COUNT();
   
   if v_rows = 0 then 
      drop temporary table if exists t_new_links;
      drop temporary table if exists t_rework_links;
      leave stored_procedure;
   end if; 
   
   if @sp_debug > 0 then 
      
      
      
      
      select v_rows as Links_required; 
      select * from  t_new_links;
   end if;
   
   fix_duplicates:
   while v_retries < 50
   do
      insert into t_rework_links( ab_eid, lnk, generated_dupe ) 
         select distinct 
                ab_eid,  
                lnk,
                count(*) as generated_dupe
         from   t_new_links
         group by lnk
         having count(*) > 1;
      SET v_num_rebuild = ROW_COUNT();
   
      if v_num_rebuild = 0 then
         leave fix_duplicates;
      else
        if @sp_debug > 0 then 
           select v_num_rebuild as generated_duplicates;
           select * from t_rework_links;
        end if;
      end if;
       
      delete N
      from   t_new_links    N,
             t_rework_links R
      where  N.ab_eid = R.ab_eid;
  
      insert t_new_links ( ab_eid, lnk )
         select ab_eid,
                concat(
          substring( v_string_set, floor( 1+ 64 * rand() ), 1), 
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 62 * rand() ), 1) ) as lnk 
      from t_rework_links;
      truncate table t_rework_links; 
      SET v_retries = v_retries + 1;
  
      if v_retries = 50 then
         set @sp_return_stat = 1;
         SIGNAL SQLSTATE '01000'
         SET MESSAGE_TEXT = 'inv_build_recipient_links: Excessive reties', MYSQL_ERRNO = 1000;
         
         drop temporary table if exists t_new_links;
         drop temporary table if exists t_rework_links;
         leave stored_procedure;      
      end if;
   end while;
   insert links( source, link_type, link, orgid,   suid,   ab_emid,   ab_eid )
      select     "L",    "abk",     lnk,  v_orgid, v_suid, p_ab_emid, ab_eid
      from   t_new_links;
     
   drop temporary table if exists t_new_links;
   drop temporary table if exists t_rework_links;
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `inv_build_single_link`( 
          IN  p_orgid      int unsigned,
          IN  p_source     char(1),
          IN  p_link_type  char(3),
          IN  p_suid       int unsigned,  -- null infers latest
          IN  p_lngid      tinyint,
          IN  p_ab_emid    int unsigned,
          IN  p_ab_eid     int unsigned,
          OUT p_lid        int unsigned,
          OUT p_link       varchar(20)
         )
stored_procedure:
begin
   declare v_lnk           varchar(20);
   declare v_string_set    char(64);
   declare v_num_rebuild   int;
   declare v_t1            datetime;
   declare v_retries       int;
   declare v_msg           varchar(255);
   declare v_rows, v_err   int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   if p_suid is null then -- when null lookup latest active survey
      select suid into p_suid 
      from   survey_used 
      where  orgid  = p_orgid
      and    active = 1
      and    date_end is null;
      SET v_rows = ROW_COUNT();
         
      if v_rows != 1 then
         set @sp_return_stat = 1, v_msg = concat( 'inv_build_single_link: not found active survey for orgid = ', p_orgid);
         SIGNAL SQLSTATE '01000'
         SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
         leave stored_procedure; 
      end if; 
   elseif p_suid = 0 then
      SET p_suid  = null; -- support entirely independant links like site main link to Trip advisor
   end if;
  
   set v_string_set  = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.-",
       v_num_rebuild = 1,
       v_retries     = 0,
       v_rows        = 0;
   while v_retries < 50 and v_rows = 0
   do
      set v_lnk = concat(
          substring( v_string_set, floor( 1+ 64 * rand() ), 1), 
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 64 * rand() ), 1),
          substring( v_string_set, floor( 1+ 62 * rand() ), 1) ); -- 62 to avoid '.-' at end
      -- insert but safeguard where duplicate for key link types
      insert links( orgid, source, link_type, link, suid, lngid, ab_emid, ab_eid )
         select p_orgid, p_source, p_link_type, v_lnk, p_suid, p_lngid, p_ab_emid, p_ab_eid from dual
         where not exists ( select * from links
                            where  link  = v_lnk
                            or (    orgid     = p_orgid 
                                and source    = p_source
                                and link_type = p_link_type
                                and ifnull(suid,0)    = ifnull(p_suid,   0)
                                and ifnull(lngid,0)   = ifnull(p_lngid,  0) 
                                and ifnull(ab_emid,0) = ifnull(p_ab_emid,0)
                                and ifnull(ab_eid,0)  = ifnull(p_ab_eid, 0) 
                                )                                
                            );
                              
      SET v_rows = ROW_COUNT(), p_lid = LAST_INSERT_ID();
      
      if v_rows = 0 then -- and p_link_type in ( "man", "mns","den", "upv", "apv", "epv" "clp" ) then
         
         -- Pick up details if insert was skipped due to existing entry
         select lid, link into p_lid, v_lnk
         from links
         where  orgid  = p_orgid 
         and source    = p_source
         and link_type = p_link_type
         and ifnull(suid,0)    = ifnull(p_suid,0)
         and ifnull(lngid,0)   = ifnull(p_lngid,0) 
         and ifnull(ab_emid,0) = ifnull(p_ab_emid,0)
         and ifnull(ab_eid,0)  = ifnull(p_ab_eid, 0) limit 1;
         SET v_rows = ROW_COUNT();
         
         if @sp_debug =1 and v_rows = 1 then select p_lid, v_lnk as reused_link; end if;   
      end if;
      SET v_retries = v_retries + 1;
  
      if v_retries = 50 then
         set @sp_return_stat = 1;
         SIGNAL SQLSTATE '01000'
         SET MESSAGE_TEXT = 'inv_build_single_link: Excessive reties', MYSQL_ERRNO = 1000;
         
         leave stored_procedure;      
      end if;
      
   end while;
   
   set p_link = v_lnk;
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `inv_email_temlate_build`( -- must set one of the first three keys to assit lookup
          INOUT p_etid                 integer unsigned,
          IN    p_orgid                integer unsigned, -- can skip if have uid
          IN    p_uid                  integer unsigned,
          -- 
          IN    p_name                 varchar(255),      -- if p_etid null must identify template type
          IN    p_lngid                tinyint unsigned,  -- if null looks up default language
          IN    p_htid                 tinyint unsigned,  -- null unless related to hot alert 
          --
          IN  p_html_email              tinyint unsigned, -- if null defaults 1
          IN  p_subject                 varchar(255),
          IN  p_body                    longtext,
          IN  p_envelope_sender_name    varchar(255),
          IN  p_envelope_sender_email   varchar(255),
          IN  p_intro_msg_via_link      varchar(255)
         )
stored_procedure:
begin
   declare v_msg           varchar(255);
   declare v_rows, v_err   int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   if p_etid is null and p_orgid is null and p_uid is null then
      set @sp_return_stat = 1, v_msg = concat( 'inv_email_temlate_build: keys p_etid/p_orgid/uid  are all ', 'null');
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;
   if p_etid is null then
      if p_orgid is null then
         select orgid into p_orgid
         from   users
         where  uid = p_uid;
      end if;
      
      select etid into p_etid
      from   email_template
      where  orgid = p_orgid 
      and    name  = p_name;
   end if;
   
   -- p_etid for update else insert ( orgid, p_name ) 
   if p_etid is not null then
      update email_template 
      set    subject = p_subject,
             body    = p_body,
             envelope_sender_name  = p_envelope_sender_name,
             envelope_sender_email = p_envelope_sender_email,
             intro_msg_via_link    = p_intro_msg_via_link
      where  etid = p_etid;
      SET v_rows = ROW_COUNT();
      
      if v_rows != 1 then
         set @sp_return_stat = 1, v_msg = concat( 'inv_email_temlate_build: unknown etid = ', p_etid);
         SIGNAL SQLSTATE '01000'
         SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
         leave stored_procedure; 
      end if;   
   else
      -- Use default language if none supplied
      if p_lngid is null then
         select lngid into p_lngid
         from   org_langs 
         where  orgid = p_orgid
         and    use_as_default = 1 
         limit 1;
      end if;
      if p_orgid is null or p_lngid is null or p_name is null then
         set @sp_return_stat = 1, v_msg = concat( 'inv_email_temlate_build: insuffient data to add template: orgid =',p_orgid, ' lngid = ', p_lngid,' name = ', p_name );
         SIGNAL SQLSTATE '01000'
         SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
         leave stored_procedure; 
      end if;
      
      insert email_template (orgid, lngid, name, html_email,  subject,    body,   envelope_sender_name,   envelope_sender_email,  intro_msg_via_link, htid) 
              values (p_orgid, p_lngid, p_name, p_html_email, p_subject, p_body, p_envelope_sender_name, p_envelope_sender_email, p_intro_msg_via_link, p_htid);
   end if;
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `inv_member_build`( 
          IN    p_orgid        integer unsigned,
          IN    p_email        varchar(60),
          IN    p_first_name   varchar(100),
          IN    p_last_name    varchar(100),
          IN    p_invite_name  varchar(255),
          IN    p_release_date datetime,
          INOUT p_ab_eid       integer unsigned       
         )
stored_procedure:
begin
   declare v_dup_allowed  tinyint;
   declare v_msg          varchar(255);
   declare v_rows, v_err  int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;   
   set @sp_return_stat = 0;
   set p_ab_eid = 0;  
   if exists ( select e.email FROM blocked_emails e WHERE e.orgid = p_orgid and email = p_email) then
      leave stored_procedure;
   end if;
   if exists ( select orgid from no_de_dupe_emails where orgid = p_orgid and email = p_email) then
      set v_dup_allowed = 1;
   else 
      set v_dup_allowed = 0;
   end if;
                                    
   
   
   
   
   
   
   
   case v_dup_allowed
   when 0 then
      insert ab_list_members ( orgid, email, first_name, last_name, 
                               invite_name, release_date, latest_status, latest_date, date_changed )
                        select p_orgid, p_email, p_first_name, p_last_name, 
                               p_invite_name, p_release_date, "NEW", p_release_date, now() 
                        from dual
                        where not exists ( select * 
                                           from ab_list_members
                                           where orgid = p_orgid
                                           and   email = p_email );                
      set v_rows = ROW_COUNT();
      if v_rows > 0 then
         set p_ab_eid = LAST_INSERT_ID();
      else
         update ab_list_members
         set    first_name   = p_first_name, 
                last_name    = p_last_name,
                release_date = p_release_date, 
                invite_name  = p_invite_name,
                date_changed = now() 
         where orgid = p_orgid
         and   email = p_email;
         set v_rows = ROW_COUNT();
      end if;
   when 1 then
      insert ab_list_members ( orgid, email, first_name, last_name, 
                               invite_name, release_date, latest_status, latest_date, date_changed )
                        select p_orgid, p_email, p_first_name, p_last_name, 
                               p_invite_name, p_release_date, "NEW", p_release_date, now() 
                        from dual
                        where not exists ( select * 
                                           from ab_list_members
                                           where orgid = p_orgid
                                           and   email = p_email
                                           and   invite_name = p_invite_name );                
      set v_rows = ROW_COUNT();
      if v_rows = 1 then
         set p_ab_eid = LAST_INSERT_ID();
      else
         update ab_list_members
         set    first_name   = p_first_name, 
                last_name    = p_last_name,
                release_date = p_release_date, 
                invite_name  = p_invite_name,
                date_changed = now() 
         where orgid = p_orgid
         and   email = p_email
         and   invite_name = p_invite_name;   
         set v_rows = ROW_COUNT();
      end if;
   end case;
   if v_rows = 0 then
      set @sp_return_stat = 1, 
      v_msg = concat( 'inv_member_build: no update for org=', p_orgid,
                      ' email=', p_email, ' first_name=', p_first_name, 'last_name=', p_last_name );
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;
end$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `inv_member_edit`( 
          IN    p_ab_eid       integer unsigned,
          IN    p_ab_emid      integer unsigned,
          IN    p_email        varchar(60),
          IN    p_first_name   varchar(100),
          IN    p_last_name    varchar(100),
          IN    p_status       varchar(15)
         )
stored_procedure:
begin
   declare v_msg          varchar(255);
   declare v_rows, v_err  int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;   
   set @sp_return_stat = 0;
   
   if p_email is not null then
      update ab_email_recipients 
      set    email = p_email
      where  ab_emid = p_ab_emid 
      and    ab_eid  = p_ab_eid 
      and    status in ("PENDING","RPENDING","SENT");
      update ab_list_members
      set    email  = p_email
      where  ab_eid = p_ab_eid;
      set v_rows = ROW_COUNT();
   end if;
     
   if p_status is not null then
      update ab_email_recipients
      set    status = p_status
      where  ab_eid  = p_ab_eid     
      and    ab_emid = p_ab_emid;
      set v_rows = ROW_COUNT();
   end if;
   if p_first_name is not null or p_last_name is not null then
      update ab_list_members
      set    first_name  = ifnull( p_first_name, first_name ),
             last_name   = ifnull( p_last_name,  last_name  ),
             invite_name = concat( ifnull( p_first_name, first_name ), " " , ifnull( p_last_name, last_name ) )
      where  ab_eid = p_ab_eid;
      set v_rows = ROW_COUNT();
   end if;
   if v_rows = 0 then
      set @sp_return_stat = 1, 
      v_msg = concat( 'inv_member_edit: no update for p_ab_eid=', ifnull(p_ab_eid, -1),' p_ab_emid=', ifnull(p_ab_emid,-1), 
                      ' first_name=', ifnull(p_first_name,""), ' last_name=', ifnull(p_last_name, "") );
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;
end$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `inv_search_distribution`( IN p_orgid         integer unsigned,
          IN p_email_pattern varchar(255)
         )
    READS SQL DATA
    DETERMINISTIC
stored_procedure:
begin
   declare v_email_pattern         varchar(255);
   declare v_rows, v_err           int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   
   
   set v_email_pattern = concat( '%',  trim(upper( p_email_pattern)), '%'); 
   if @sp_debug = 1 then
      select v_email_pattern as v_email_pattern;
   end if;
   select m.ab_eid, m.email, m.first_name, m.last_name,
          m.latest_ab_emid, 
          m.latest_status,
          m.latest_date 
   from   ab_list_members m
   where  m.orgid = p_orgid
   and    upper( m.email ) like v_email_pattern;
   
   
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `inv_search_distribution_gr`( IN p_orgid         integer unsigned,
          IN p_email_pattern varchar(255),
          IN p_row_offset    integer unsigned,
          IN p_row_limit     integer unsigned,
          IN p_sort_col      varchar(12), -- "email", "name", "status" or "date"
          IN p_sort_asc      tinyint unsigned,
          OUT p_found_rows   integer unsigned
         )
stored_procedure:
begin
   declare v_email_pattern         varchar(255);
   declare v_rows, v_err           int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   
   -- playing safe to be deliberately case insensive (default in mysql)
   set v_email_pattern = concat( '%',  trim(upper( p_email_pattern)), '%'); 
   if @sp_debug = 1 then
      select v_email_pattern as v_email_pattern;
   end if;
   if p_sort_col = "email"  then -- index support to avoid sort
      if p_sort_asc = 1 then
         select SQL_CALC_FOUND_ROWS
                m.ab_eid, m.email, m.first_name, m.last_name,
                m.latest_ab_emid, 
                m.latest_status,
                m.latest_date 
         from   ab_list_members m
         where  m.orgid = p_orgid
         and    ( upper( m.email ) like v_email_pattern or upper( m.invite_name ) like v_email_pattern )
         order by email
         limit  p_row_offset, p_row_limit;
         set p_found_rows = FOUND_ROWS();
      else
         select SQL_CALC_FOUND_ROWS
                m.ab_eid, m.email, m.first_name, m.last_name,
                m.latest_ab_emid, 
                m.latest_status,
                m.latest_date 
         from   ab_list_members m
         where  m.orgid = p_orgid
         and    ( upper( m.email ) like v_email_pattern or upper( m.invite_name ) like v_email_pattern )
         order by email desc
         limit  p_row_offset, p_row_limit;
         set p_found_rows = FOUND_ROWS();
      end if;
   else
      if p_sort_asc = 1 then
         select SQL_CALC_FOUND_ROWS
                m.ab_eid, m.email, m.first_name, m.last_name,
                m.latest_ab_emid, 
                m.latest_status,
                m.latest_date 
         from   ab_list_members m
         where  m.orgid = p_orgid
         and    ( upper( m.email ) like v_email_pattern or upper( m.invite_name ) like v_email_pattern )
         order by  -- flexible order reporting, no sort cost saving, just orgid search arg
               case p_sort_col  
               -- when "email"   then m.email
               when "name"    then m.invite_name
               when "status"  then m.latest_status
               else                m.latest_date
               end
         limit  p_row_offset, p_row_limit;
         set p_found_rows = FOUND_ROWS();
      else
         select SQL_CALC_FOUND_ROWS
                m.ab_eid, m.email, m.first_name, m.last_name,
                m.latest_ab_emid, 
                m.latest_status,
                m.latest_date 
         from   ab_list_members m
         where  m.orgid = p_orgid
         and    ( upper( m.email ) like v_email_pattern or upper( m.invite_name ) like v_email_pattern )
         order by  -- flexible order reporting, no sort cost saving, just orgid search arg
               case p_sort_col  
               -- when "email"   then m.email
               when "name"    then m.invite_name
               when "status"  then m.latest_status
               else                m.latest_date
               end desc
         limit  p_row_offset, p_row_limit;
         set p_found_rows = FOUND_ROWS();
      end if;
   end if;  
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `mon_rpt_acc_export`( 
        
         )
stored_procedure:
begin
   declare v_rows, v_err  int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   
   truncate table ImportDB.IM_REPORTING_CHECK;
   
   CREATE TEMPORARY TABLE t_site_ids ENGINE=MEMORY
      select S.orgid,
             min(U.uid) as min_uid, 
             min(H.p_orgid ) as pms_orgid
      from  organisation S
      left outer join users U
            on  S.orgid        = U.orgid
            and U.active       = 1
            and U.contact_type = "main"
      left outer join org_relation H
            on  S.orgid    = H.c_orgid
            and H.p_type   = "P"
            and H.p_active = 1
     where S.type = "S"
     group by S.orgid;
   CREATE TEMPORARY TABLE t_site_data ENGINE=MEMORY
      select S.orgid, S.remote_ref as ref, S.name as company, S.active, S.system_status, 
             P.name as pms, S.date_last_pms_file,
             U.email, U.first_name, U.last_name
      from  t_site_ids I
      inner join organisation S
         on I.orgid = S.orgid
      left  outer join users U
         on I.min_uid  = U.uid
      left outer join organisation P
         on I.pms_orgid = P.orgid;
   
   drop temporary table t_site_ids;
   
 
   
   CREATE TEMPORARY TABLE t_IM_RPT_DATA ENGINE=MEMORY
      select pms, ref, company,  email,  first_name, last_name, rpt_type, rpt_detail 
      from ImportDB.IM_REPORTING_CHECK where 1=0;
   
   insert t_IM_RPT_DATA( pms, ref, company,  email,  first_name, last_name, rpt_type, rpt_detail )
      select pms, ref, company, email, first_name, last_name,
             "Acc ON - Last pms file date" as rpt_type,
             ifnull( date_last_pms_file,'No data') as rpt_detail
      from   t_site_data
      where  active        = 1 
      and    system_status = 1;
      
      
   
   
   CREATE TEMPORARY TABLE t_im_rpt_run ENGINE=MEMORY
      select A.orgid, 
             max(M.date_changed) as max_date_changed
      from   t_site_data A
         left outer join ab_list_members M
            on A.orgid = M.orgid
      where A.active = 1 
      and   A.system_status = 1
      group by A.orgid;
      
   insert t_IM_RPT_DATA( pms, ref, company,  email,  first_name, last_name, rpt_type, rpt_detail )
      select pms, ref, company, email, first_name, last_name,
             "Acc ON - Last email recieved date"     as rpt_type,
             ifnull( T.max_date_changed,'No data') as rpt_detail
      from   t_im_rpt_run  T,
             t_site_data  C
      where  T.orgid  = C.orgid;
      
   
   drop temporary table t_im_rpt_run;
   
   
   CREATE TEMPORARY TABLE t_im_rpt_run ENGINE=MEMORY
      select orgid, 
             count(*) as  num_files, 
             sum(email_rows) as sum_email_rows,
             sum(total_rows) as sum_total_rows,
             100*sum(email_rows) / case sum(total_rows) when 0 then null else sum(total_rows) end as email_prcnt
             
   
   
      from   im_import
      where  entry_time > DATE_ADD(now(), INTERVAL -7 DAY)
      
      group by orgid;
      
      
      
   insert t_IM_RPT_DATA( pms, ref, company,  email,  first_name, last_name, rpt_type, rpt_detail )
      select pms, ref, company, email, first_name, last_name,
             "Acc ON - 7 day  Email % processed ok"     as rpt_type,
             concat( round(email_prcnt,1), "% across ", num_files, " files due to ", 
                     sum_email_rows, " emails in ", sum_total_rows, " total" )
             as rpt_detail
      from       t_im_rpt_run  T
      inner join t_site_data  C
         on    T.orgid  = C.orgid
         and   C.system_status = 1
         and   C.active        = 1;
         
      
   
   drop temporary table t_im_rpt_run;
   
   CREATE TEMPORARY TABLE t_qnid_list ENGINE=MEMORY
      select C.orgid, S.qnid,
             DATE_ADD(CURDATE(), INTERVAL -35 DAY) as start_date,
             DATE_ADD(CURDATE(), INTERVAL   0 DAY) as end_date
      from t_site_data C,
           survey_used  S
      where C.orgid = S.orgid
      and   C.system_status = 1
      and   C.active        = 1
      and   S.active        = 1
      and   ifnull( S.date_end, now() ) > DATE_ADD(CURDATE(), INTERVAL -35 DAY);
   
   
   
   CREATE TEMPORARY TABLE t_rid_count_day ENGINE=MEMORY
      select L.orgid, 
             datediff(now(), R.date_started ) as days_back, 
             count(*) as rids
      from  t_qnid_list L,
            rids        R
      where R.qnid  = L.qnid
      and   R.date_started >= L.start_date
      and   R.date_started <  L.end_date
      and   R.status = 1
      group by L.orgid, datediff(now(), R.date_started );
   
   
   CREATE TEMPORARY TABLE t_rid_count_block ENGINE=MEMORY
      select orgid, 
             ifnull( sum(case sign(days_back -8) when -1 then rids else null end), 0) as w1_rids,
             ifnull( sum(case sign(days_back -7) when  1 then rids else null end), 0) as w2_5_rids,
             round( ifnull( sum(case sign(days_back -7) when  1 then rids else null end)/4.0, 0),1 ) as w2_5_av_wk 
      from   t_rid_count_day
      group by orgid;
   
   insert t_IM_RPT_DATA( pms, ref, company,  email,  first_name, last_name, rpt_type, rpt_detail )
      select pms, ref, company, email, first_name, last_name,
             "Acc ON - results 7 day count"   as rpt_type,
             concat( w1_rids, " (" , w2_5_av_wk, ") past week & (prior 4 week av)" ) as rpt_detail
      from t_site_data C,
           t_rid_count_block B
      where C.orgid = B.orgid
      and   C.system_status = 1
      and   C.active        = 1
      order by w1_rids;
   
   drop temporary table t_qnid_list;
   drop temporary table t_rid_count_day;
   drop temporary table t_rid_count_block;
   insert  ImportDB.IM_REPORTING_CHECK( pms, ref, company,  email,  first_name, last_name, rpt_type, rpt_detail )
   select  pms, ref, company,  email,  first_name, last_name, rpt_type, rpt_detail
   from    t_IM_RPT_DATA
   where  ltrim( company ) is not null
   order by company, rpt_type;
   drop temporary table t_site_data;
   drop temporary table t_IM_RPT_DATA;
 
   if @sp_debug = 1 then
      select rpt_type, rpt_detail, pms, ref, company,  email,  first_name, last_name 
      from ImportDB.IM_REPORTING_CHECK order by seq;
   end if;
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `mon_rpt_low_counts`( 
        
         )
stored_procedure:
begin
   declare v_rows, v_err  int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   
   truncate table ImportDB.IM_REPORTING_CHECK;
   
   CREATE TEMPORARY TABLE t_site_ids ENGINE=MEMORY
      select S.orgid,
             min(U.uid) as min_uid, 
             min(H.p_orgid ) as pms_orgid
      from  organisation S
      left outer join users U
            on  S.orgid        = U.orgid
            and U.active       = 1
            and U.contact_type = "main"
      left outer join org_relation H
            on  S.orgid    = H.c_orgid
            and H.p_type   = "P"
            and H.p_active = 1
     where S.type = "S"
     group by S.orgid;
   CREATE TEMPORARY TABLE t_site_data ENGINE=MEMORY
      select S.orgid, S.remote_ref as ref, S.name as company, S.active, S.system_status, 
             P.name as pms, S.date_last_pms_file,
             U.email, U.first_name, U.last_name
      from  t_site_ids I
      inner join organisation S
         on I.orgid = S.orgid
      left  outer join users U
         on I.min_uid  = U.uid
      left outer join organisation P
         on I.pms_orgid = P.orgid;
   
   drop temporary table t_site_ids;
   
 
 
   
   
   
   CREATE TEMPORARY TABLE t_im_rpt_run ENGINE=MEMORY
      select A.orgid, min(B.run_date) as min_date
      from       t_site_data   A
      inner join ab_emails    B
         on   A.orgid  = B.orgid
         
         and  A.active = 1
         and  A.system_status = 0
         and  B.status in ("PENDING", "RPENDING")
      group by A.orgid;
   insert ImportDB.IM_REPORTING_CHECK( pms, ref, company,  email,  first_name, last_name, rpt_type, rpt_detail )
      select C.pms, C.ref, C.company, C.email, C.first_name, C.last_name,
             "Acc OFF - 1st distribution date" as rpt_type,
             ifnull(T.min_date, "no data") as rpt_detail
      from       t_site_data  C
      left outer join t_im_rpt_run  T
         on T.orgid  = C.orgid
       where C.system_status = 0
       and   C.active = 1
      order by T.min_date;
   insert ImportDB.IM_REPORTING_CHECK( pms, ref, company,  email,  first_name, last_name, rpt_type, rpt_detail ) values ("","","","","","","","");
   drop temporary table t_im_rpt_run;
   
  
   
   
   insert ImportDB.IM_REPORTING_CHECK( pms, ref, company,  email,  first_name, last_name, rpt_type, rpt_detail )
      select pms, ref, company, email, first_name, last_name,
             "Acc ON - Last file >3 days ago" as rpt_type,
             ifnull( date_last_pms_file,'No data') as rpt_detail
      from   t_site_data
      where  active        = 1 
      and    system_status = 1
      and    ifnull( date_last_pms_file, "1999/12/1") < DATE_ADD(now(), INTERVAL -3 DAY);
   insert ImportDB.IM_REPORTING_CHECK( pms, ref, company,  email,  first_name, last_name, rpt_type, rpt_detail ) values ("","","","","","","","");
   
   CREATE TEMPORARY TABLE t_im_rpt_run ENGINE=MEMORY
      select A.orgid, 
             max(M.date_changed) as max_date_changed
      from   t_site_data A
         left outer join ab_list_members M
            on A.orgid = M.orgid
      where A.active = 1 
      and   A.system_status = 1
      group by A.orgid
      having max( M.date_changed) < DATE_ADD(now(), INTERVAL -5 DAY) or max(M.date_changed) is null;
   insert ImportDB.IM_REPORTING_CHECK( pms, ref, company,  email,  first_name, last_name, rpt_type, rpt_detail )
      select pms, ref, company, email, first_name, last_name,
             "Acc ON - Last email >5 days ago"     as rpt_type,
             ifnull( T.max_date_changed,'No data') as rpt_detail
      from   t_im_rpt_run  T,
             t_site_data  C
      where  T.orgid  = C.orgid
      order by max_date_changed desc;
   insert ImportDB.IM_REPORTING_CHECK( pms, ref, company,  email,  first_name, last_name, rpt_type, rpt_detail ) values ("","","","","","","","");
   drop temporary table t_im_rpt_run;
   
   
   CREATE TEMPORARY TABLE t_im_rpt_run ENGINE=MEMORY
      select orgid, 
             count(*) as  num_files, 
             sum(email_rows) as sum_email_rows,
             sum(total_rows) as sum_total_rows,
             100*sum(email_rows) / case sum(total_rows) when 0 then null else sum(total_rows) end as email_prcnt
             
   
   
      from   im_import
      where  entry_time > DATE_ADD(now(), INTERVAL -7 DAY)
      and    status >= 1
      group by orgid;
      
      
      
      
   insert ImportDB.IM_REPORTING_CHECK( pms, ref, company,  email,  first_name, last_name, rpt_type, rpt_detail )
      select pms, ref, company, email, first_name, last_name,
             "Acc ON - 7 day  Email % processed ok < 50%"     as rpt_type,
             concat( round(email_prcnt,1), "% across ", num_files, " files due to ", 
                     sum_email_rows, " emails in ", sum_total_rows, " total" )
             as rpt_detail
      from       t_im_rpt_run  T
      inner join t_site_data  C
         on    T.orgid  = C.orgid
         and   C.system_status = 1
         and   C.active        = 1 
         and   T.email_prcnt   < 50
      order by  email_prcnt;
   insert ImportDB.IM_REPORTING_CHECK( pms, ref, company,  email,  first_name, last_name, rpt_type, rpt_detail ) values ("","","","","","","","");
   drop temporary table t_im_rpt_run;
   
   CREATE TEMPORARY TABLE t_qnid_list ENGINE=MEMORY
      select C.orgid, S.qnid,
             DATE_ADD(CURDATE(), INTERVAL -35 DAY) as start_date,
             DATE_ADD(CURDATE(), INTERVAL   0 DAY) as end_date
      from t_site_data C,
           survey_used  S
      where C.orgid = S.orgid
      and   C.system_status = 1
      and   C.active        = 1
      and   S.active        = 1
      and   ifnull( S.date_end, now() ) > DATE_ADD(CURDATE(), INTERVAL -35 DAY);
   
   
   
   CREATE TEMPORARY TABLE t_rid_count_day ENGINE=MEMORY
      select L.orgid, 
             datediff(now(), R.date_started ) as days_back, 
             count(*) as rids
      from  t_qnid_list L,
            rids        R
      where R.qnid  = L.qnid
      and   R.date_started >= L.start_date
      and   R.date_started <  L.end_date
      and   R.status = 1
      group by L.orgid, datediff(now(), R.date_started );
   
   
   CREATE TEMPORARY TABLE t_rid_count_block ENGINE=MEMORY
      select orgid, 
             ifnull( sum(case sign(days_back -8) when -1 then rids else null end), 0) as w1_rids,
             ifnull( sum(case sign(days_back -7) when  1 then rids else null end), 0) as w2_5_rids,
             round( ifnull( sum(case sign(days_back -7) when  1 then rids else null end)/4.0, 0),1 ) as w2_5_av_wk 
      from   t_rid_count_day
      group by orgid;
   
   insert ImportDB.IM_REPORTING_CHECK( pms, ref, company,  email,  first_name, last_name, rpt_type, rpt_detail )
      select pms, ref, company, email, first_name, last_name,
             "Acc ON - results 7 day count"   as rpt_type,
             concat( w1_rids, " (" , w2_5_av_wk, ") past week & (prior 4 week av)" ) as rpt_detail
      from t_site_data C,
           t_rid_count_block B
      where C.orgid = B.orgid
      and   C.system_status = 1
      and   C.active        = 1
      order by w1_rids;
   
   drop temporary table t_qnid_list;
   drop temporary table t_rid_count_day;
   drop temporary table t_rid_count_block;
   drop temporary table t_site_data;
 
   if @sp_debug = 1 then
      select rpt_type, rpt_detail, pms, ref, company,  email,  first_name, last_name 
      from ImportDB.IM_REPORTING_CHECK order by seq;
   end if;
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `org_block_email`( 
          IN  p_orgid       integer unsigned,
          IN  p_email       varchar(60)
         )
stored_procedure:
begin
   declare v_orgid        integer unsigned;
   declare v_rows, v_err  int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;   
   set @sp_return_stat = 0;
   
 
    insert into blocked_emails( orgid, email ) 
       select p_orgid, p_email
       from   dual
       where not exists ( select email
                          from   blocked_emails 
                          where  orgid = p_orgid
                          and    email = p_email );
    
   SELECT e.email 
   FROM blocked_emails e 
   WHERE e.orgid = p_orgid;
end$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `org_build`( INOUT p_orgid              integer unsigned,
          IN  p_action               char(1), 
          IN  p_dflt_lngid           integer unsigned,
          IN  p_type                 char(1),
          IN  p_active               tinyint unsigned,
          IN  p_system_status        int unsigned,
          IN  p_name                 varchar(255),
          IN  p_tel                  varchar(255),
          IN  p_fax                  varchar(255),
          IN  p_address1             varchar(255),
          IN  p_address2             varchar(255),
          IN  p_postcode             varchar(255),
          IN  p_city                 varchar(255),
          IN  p_province             varchar(255),
          IN  p_country              varchar(255),
          IN  p_no_of_rooms          int unsigned,
          IN  p_star_grading         varchar(255),
          IN  p_remote_ref           varchar(255),
          IN  p_monthly_price        varchar(255),
          IN  p_payment_method       varchar(255),
          IN  p_payment_frequency    varchar(255),
          IN  p_pricing_notes        text,
          IN  p_questionnaire_instructions text,
          IN  p_reporting_instructions text,
          IN  p_report_recipients    text,
          IN  p_hot_alert_details    text,
          IN  p_send_invitation_delay_day int unsigned,
          IN  p_max_invitation_period_months int unsigned,
          IN  p_no_of_reminders      int unsigned,
          IN  p_reminder_gap_days    int unsigned,
          IN  p_notify_no_action_days int unsigned,
          IN  p_ta_ref                 varchar(255)
         )
stored_procedure:
begin
   declare v_rows, v_err  int default 0;
   
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 1;
   case 
   when p_action = "I" then
      insert organisation(
             type, active, system_status,
             name, tel, fax,address1, address2, postcode, city, province, country,
             no_of_rooms, star_grading, remote_ref,
             monthly_price, payment_method, payment_frequency,
             pricing_notes, questionnaire_instructions, reporting_instructions, report_recipients,
             hot_alert_details, send_invitation_delay_day, max_invitation_period_months,
             no_of_reminders, reminder_gap_days, notify_no_action_days, ta_ref)
      values (
             p_type, p_active, p_system_status,
             p_name, p_tel, p_fax, p_address1, p_address2, p_postcode, p_city, p_province, p_country,
             p_no_of_rooms, p_star_grading, p_remote_ref,
             p_monthly_price, p_payment_method, p_payment_frequency,
             p_pricing_notes, p_questionnaire_instructions, p_reporting_instructions, p_report_recipients,
             p_hot_alert_details, 
             ifnull( p_send_invitation_delay_day,    2), 
             ifnull( p_max_invitation_period_months, 2),
             ifnull( p_no_of_reminders,   2),
             ifnull( p_reminder_gap_days, 2),
             ifnull( p_notify_no_action_days, 2) , p_ta_ref );
      SET p_orgid = LAST_INSERT_ID(), v_rows = ROW_COUNT();
      
      if @sp_debug = 1 then
         select p_orgid as p_orgid;
      end if;
         
      insert ha_note_statuses ( orgid, name, active, is_initial_state ) 
         select p_orgid, S.name, S.active, S.is_initial_state
         from   ha_note_statuses S
         where  S.orgid  = 1
         and    S.active = 1;
   
   when p_action = "U" then
      update organisation
      set    type   = ifnull( p_type, type ),
             active = ifnull( p_active, active ),
             system_status = ifnull( p_system_status, system_status ),
             name = ifnull( p_name, name ),
             tel  = ifnull( p_tel, tel ),
             fax  = ifnull( p_fax, fax ),
             address1 = ifnull( p_address1, address1 ),
             address2 = ifnull( p_address2, address2 ),
             postcode = ifnull( p_postcode, postcode ),
             city     = ifnull( p_city, city ),
             province = ifnull( p_province, province ),
             country  = ifnull( p_country, country ),
             no_of_rooms  = ifnull( p_no_of_rooms, no_of_rooms ),
             star_grading = ifnull( p_star_grading, star_grading ),
             remote_ref   = ifnull( p_remote_ref, remote_ref ),
             monthly_price     = ifnull( p_monthly_price, monthly_price ),
             payment_method    = ifnull( p_payment_method, payment_method ),
             payment_frequency = ifnull( p_payment_frequency, payment_frequency ),
             pricing_notes     = ifnull( p_pricing_notes, pricing_notes ),
             questionnaire_instructions = ifnull( p_questionnaire_instructions, questionnaire_instructions ),
             reporting_instructions     = ifnull( p_reporting_instructions, reporting_instructions ),
             report_recipients = ifnull( p_report_recipients, report_recipients ),
             hot_alert_details = ifnull( p_hot_alert_details, hot_alert_details ),
             send_invitation_delay_day    = ifnull( p_send_invitation_delay_day, send_invitation_delay_day ),
             max_invitation_period_months = ifnull( p_max_invitation_period_months, max_invitation_period_months ),
             no_of_reminders   = ifnull( p_no_of_reminders, no_of_reminders ),
             reminder_gap_days = ifnull( p_reminder_gap_days, reminder_gap_days ),
             notify_no_action_days = ifnull( p_notify_no_action_days, notify_no_action_days ),
             ta_ref = ifnull( p_ta_ref, ta_ref)
      where  
             orgid = p_orgid;
     
      SET v_rows = ROW_COUNT();
      if v_rows != 1 then 
         set @sp_return_stat = 1;
         SIGNAL SQLSTATE '01000'
         SET MESSAGE_TEXT = 'org_build: Organisation update failed', MYSQL_ERRNO = 1000;
         leave stored_procedure; 
      end if;
   else
      set @sp_return_stat = 1;
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = 'org_build: Action unknown', MYSQL_ERRNO = 1000;  
      leave stored_procedure; 
   end case;
   
   if p_dflt_lngid is not null and v_rows = 1 then
      call org_lang_assoc (
          "A",          
          p_orgid,      
          p_dflt_lngid, 
          1             
           );
   end if;
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `org_delivery_search`( IN p_search_pattern varchar(255)
         )
stored_procedure:
begin
   declare v_msg            varchar(255);
   declare v_search_pattern varchar(255);
   declare v_rows, v_err  int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   
   set v_search_pattern = concat( '%', p_search_pattern, '%' );
   
   select o.type, o.name, o.orgid, o.active ,u.uid, u.email  
   from      organisation o 
   left join users u
      on o.orgid = u.orgid 
   where o.type in ('S', 'G', 'A')
   and (    o.name  like v_search_pattern
         or o.orgid    = p_search_pattern 
         or u.email like v_search_pattern )
   order by o.name;
    
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `org_ensure_email_template`( 
          IN  p_orgid           integer unsigned,
          IN  p_lngid           tinyint unsigned
         )
stored_procedure:
begin
   declare v_rows, v_err  int default 0;
   declare v_root_orgid   integer unsigned;
          
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;  
   set @sp_return_stat = 0;
   select orgid into v_root_orgid from organisation where name = "Root Admin";
   
   
  
      insert email_template( orgid, lngid, name, html_email, subject, body, envelope_sender_name, envelope_sender_email, intro_msg_via_link, htid )
         select p_orgid, lngid, name, html_email, subject, body, envelope_sender_name, envelope_sender_email, intro_msg_via_link, htid
         from email_template R
         where R.orgid = v_root_orgid
         and   R.lngid = p_lngid
         and not exists (select * 
                         from email_template E
                         where E.orgid = p_orgid 
                         and   E.lngid = p_lngid
                         and   R.name  = E.name
                         and  ( (R.htid = E.htid) or (R.htid is null and E.htid is null ) )
                         );
   
end$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `org_evaluate_survey_change`( IN p_orgid          integer unsigned,
          IN p_is_new_survey  tinyint unsigned
         )
stored_procedure:
begin
   declare v_rpid         integer unsigned;
   declare v_no_data      tinyint;
   declare v_msg          varchar(255);
   declare v_rows, v_err  int default 0;
  
   declare curse1 cursor for
      select R.rpid
      from   report R 
      where  R.orgid   = p_orgid
      and    R.is_user = 0;
   
   declare CONTINUE handler for NOT FOUND
   begin
      set v_no_data = TRUE;
   end;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   if not exists( select orgid from organisation where orgid = p_orgid ) then
      set @sp_return_stat = 1, v_msg = concat( 'org_evaluate_survey_change: not found orgid ', p_orgid);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;
   
   
   
   
   
   
   
   
   
   
   
   
   
   if exists ( select * from report R where R.orgid = p_orgid and R.is_user = 0 ) then
      open curse1;
   
      set v_no_data = 0;
      curse1_loop: 
      loop 
         fetch curse1 into v_rpid;
         if v_no_data then leave curse1_loop; end if;     
      
         
      
         call rpt_report_wipeout ( v_rpid );
      end loop;
      close curse1;
   end if;
   
   update report_recipient P,
          report R
   set    P.active = 0
   where  P.rpid   = R.rpid
   and    R.orgid  = p_orgid
   and    P.active = 1;
   
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `org_get_rid_notifies`( 
          IN  p_search_window_days  smallint unsigned, -- cuttoff  days to avoid search of all results 
          IN  p_time_now            datetime           -- typically null for now(),but can set historical date
         )
stored_procedure:
begin
   declare v_orgid        integer unsigned;
   declare v_rows, v_err  int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;   
   set @sp_return_stat = 0;
   if p_time_now is null then 
      set p_time_now = now();
   end if;
   
   drop temporary table if exists t_org_rid_cutoff;
   
   -- get good sargs before dip into rids   
   create temporary table t_org_rid_cutoff ENGINE=MEMORY as
      select O.orgid,  L.lngid,
             O.name as org_name,
             DATE_ADD( p_time_now, INTERVAL - p_search_window_days DAY ) as start_date, 
             p_time_now as end_date
      from   organisation O,
             org_langs    L
      where  L.orgid  = O.orgid
      and    O.active = 1
      and    O.type   = "S"
      and    O.rid_notify     = 1
      and    L.use_as_default = 1;
      
   if @sp_debug = 1 then select * from t_org_rid_cutoff; end if;
   select O.orgid,
          E.etid,
          L.lngid, -- using orgs default language 
          R.rid,
          -- Who to notify details
          N.onlid, 
          N.email as notify_email,
          -- Result details
          R.email as guest_email,
          R.name  as guest_name,
          R.last_update as date_completed,
          -- Template details 
          L.name as language,
          O.org_name,
          E.html_email, 
          -- 
          E.envelope_sender_name, 
          E.envelope_sender_email,
          E.subject, 
          E.body
          -- E.intro_msg_via_link
   from   t_org_rid_cutoff O
   inner join  rids R
      on  O.orgid        = R.orgid
      and R.last_update >= O.start_date
      and R.last_update  < O.end_date
      and R.status       = 1
      and R.notify_sent  = 0
   inner join org_notify_list N
      on  O.orgid  = N.orgid
      and N.type   = "RR"  -- Response receievd
   inner join  language   L
      on  O.lngid  = L.lngid   
   left outer join email_template  E
      on  O.orgid  = E.orgid 
      and E.lngid  = O.lngid 
      and E.name   = "notify_rid_recieved";
   drop temporary table t_org_rid_cutoff;
   
end$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `org_get_TA_invites`( 
          IN  p_search_window_days  smallint unsigned, -- cuttoff  days to avoid search of all results 
          IN  p_time_now            datetime           -- typically null for now(),but can set historical date
         )
stored_procedure:
begin
   declare v_orgid        integer unsigned;
   declare v_rows, v_err  int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;   
   set @sp_return_stat = 0;
   if p_time_now is null then 
      set p_time_now = now();
   end if;
   
   drop temporary table if exists t_org_ta_cutoff;
   
   -- get good sargs before dip into rids   
   create temporary table t_org_ta_cutoff ENGINE=MEMORY as
      select O.orgid,  L.lngid, O.ta_invite_days,
             DATE_ADD( p_time_now, INTERVAL - (O.ta_invite_days + p_search_window_days) DAY ) as start_date, 
             DATE_ADD( p_time_now, INTERVAL - O.ta_invite_days DAY ) as end_date,
             O.ta_ref,
             O.city
      from   organisation O,
             org_langs    L
      where  L.orgid  = O.orgid
      and    O.active = 1
      and    O.type   = "S"
      and    O.ta_invite_days > 0
      and    L.use_as_default = 1
      and    O.ta_ref is not null;  -- Trip advisor Property "location id"
      
   if @sp_debug = 1 then select * from t_org_ta_cutoff; end if;
    -- 8/5/14 Agreed:
    -- (a) first release only offer email invite in site default lange
    -- (b) Trip advisor link to widget wil be our own link specific to each property
    --     which will be manually configured
    --     Any tie with user details/language not initially required.
    --
   select O.orgid,
          E.etid,
          L.lngid, -- recipient language not available, using orgs default
          O.ta_ref,
          R.rid,
          -- Result details
          R.email as guest_email,
          R.name  as guest_name,
          R.last_update date_completed,
          O.city,  -- of org as recipients home city not available
          -- Template details 
          L.name as language,
          case L.lngid when O.lngid then 1 else 0 end as dflt_lang,
          E.html_email, 
          -- return data where required to be clear on email content
          case L.lngid when O.lngid then E.envelope_sender_name  else null end as envelope_sender_name, 
          case L.lngid when O.lngid then E.envelope_sender_email else null end as envelope_sender_email,
          case L.lngid when O.lngid then E.subject               else null end as subject, 
          case L.lngid when O.lngid then E.body                  else null end as body, 
          case L.lngid when O.lngid then null    else E.intro_msg_via_link end as intro_msg_via_link
   from   t_org_ta_cutoff O
   inner join  rids R
      on  O.orgid        = R.orgid
      and R.last_update >= O.start_date
      and R.last_update  < O.end_date
      and R.status       = 1
      and R.ta_invite_date is null
   left outer join email_template  E
      on  O.orgid  = E.orgid 
      and E.lngid  = O.lngid  -- THis locks templates retuned to just default language
      and E.name   = "TA_invite"
   left outer join  language   L
      on  E.lngid  = L.lngid;
   -- if alternative languages can be provided for recipients to pick from use of distributions intro_msg_via_link idea
   -- concern about
   
   drop temporary table t_org_ta_cutoff;
   
end$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `org_lang_assoc`( 
          IN  p_action          char(1), 
          IN  p_orgid           integer unsigned,
          IN  p_lngid           tinyint unsigned,
          IN  p_use_as_default  tinyint unsigned
         )
stored_procedure:
begin
   declare v_rows, v_err  int default 0;
   declare v_olid                  integer unsigned;
   declare v_old_use_as_default    tinyint unsigned;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;  
   set @sp_return_stat = 0;
   
   case  
   when p_action = "A" then
      
      if ( exists ( select * from org_langs 
                    where orgid = p_orgid and use_as_default = 1 and lngid != p_lngid ) ) 
      then
         update org_langs
         set    use_as_default = 0
         where  orgid = p_orgid
         and    use_as_default = 1;
      end if;
      
      if ( exists ( select * from org_langs 
                    where orgid = p_orgid and lngid = p_lngid ) ) 
      then
         update org_langs
         set    use_as_default = p_use_as_default
         where  orgid = p_orgid
         and    lngid = p_lngid;
      else
         insert org_langs( lngid, orgid, use_as_default )
            values ( p_lngid, p_orgid, p_use_as_default );
     
         set v_olid = LAST_INSERT_ID();
         if @sp_debug = 1 then
            select v_olid as v_olid;
         end if;
     end if;
     
   when p_action = "D" then
      
      select  use_as_default into v_old_use_as_default
      from    org_langs
      where   orgid = p_orgid
      and     lngid = p_lngid;
           
      if v_old_use_as_default = 1 then
         set @sp_return_stat = 1;
         SIGNAL SQLSTATE '01000'
         SET MESSAGE_TEXT = 'org_lang_assoc: Cannot delete lang for org while default=1', MYSQL_ERRNO = 1000;
         leave stored_procedure;
      else
         delete from org_langs
         where   orgid = p_orgid
         and     lngid = p_lngid;
      
         SET v_rows = ROW_COUNT();
         if v_rows != 1 then
            set @sp_return_stat = 1;
            SIGNAL SQLSTATE '01000'
            SET MESSAGE_TEXT = 'org_lang_assoc: no delete', MYSQL_ERRNO = 1000;
            leave stored_procedure;
         end if;
      end if;      
   else
      set @sp_return_stat = 1;
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = 'org_lang_assoc: Action unknown', MYSQL_ERRNO = 1000;
      leave stored_procedure;
   end case;
end$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `org_log_rid_notify_dispatched`( 
          IN  p_rid integer unsigned
         )
stored_procedure:
begin
   declare v_msg          varchar(255);
   declare v_rows, v_err  int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;   
   set @sp_return_stat = 0;
   update rids
   set    notify_sent = 1
   where  rid = p_rid;
   SET v_rows = ROW_COUNT();
      
   if v_rows != 1 then
      set @sp_return_stat = 1, v_msg = concat( 'org_log_rid_notify_dispatched  : unknown rid = ', p_rid);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;   
end$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `org_log_TA_invite_dispatched`( 
          IN  p_rid integer unsigned
         )
stored_procedure:
begin
   declare v_msg          varchar(255);
   declare v_rows, v_err  int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;   
   set @sp_return_stat = 0;
   update rids
   set    ta_invite_date = now()
   where  rid = p_rid;
   SET v_rows = ROW_COUNT();
      
   if v_rows != 1 then
      set @sp_return_stat = 1, v_msg = concat( 'org_log_TA_invite_dispatched: unknown rid = ', p_rid);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;   
end$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `org_org_assoc`( 
          IN  p_action          char(1), 
          IN  p_orgid           integer unsigned,
          IN  p_parent_orgid    integer unsigned
         )
stored_procedure:
begin
   declare v_rows, v_err  int default 0;
   declare v_ohid                  integer unsigned;
   declare v_old_use_as_default    tinyint unsigned;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end; 
   set @sp_return_stat = 0;
   
   case  
   when p_action = "A" then
      
      if not ( exists ( select * from org_hierarchy 
                        where orgid = p_orgid and parent_orgid = p_parent_orgid ) ) 
      then
         insert org_hierarchy( parent_orgid, orgid )
            values ( p_parent_orgid, p_orgid );
     
         set v_ohid = LAST_INSERT_ID();
         if @sp_debug = 1 then
            select v_ohid as v_ohid;
         end if;
     end if;
     
   when p_action = "D" then
      delete from org_hierarchy
      where   orgid = p_orgid
      and     parent_orgid = p_parent_orgid;
      
      SET v_rows = ROW_COUNT();
      if v_rows != 1 then
         set @sp_return_stat = 1;
         SIGNAL SQLSTATE '01000'
         SET MESSAGE_TEXT = 'org_org_assoc: no delete', MYSQL_ERRNO = 1000;
         leave stored_procedure; 
      end if;      
   else
      set @sp_return_stat = 1;
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = 'org_org_assoc: Action unknown', MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end case;
end$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `org_SITE_STATS`( 
          IN  p_orgid                integer unsigned,
          IN  p_stats_start_time     datetime,
          IN  p_stats_end_time       datetime,
          OUT p_site_has_pms         tinyint,
          OUT p_warn_no_upload_days  tinyint,
          OUT p_date_last_pms_file   datetime,
          OUT p_warn_no_invite_days  tinyint,
          OUT p_ab_max_date_changed  datetime
         )
stored_procedure:
begin
   declare v_last_year_start,  
           v_last_year_end,
           v_diff_month_start      datetime;
   
   declare v_org_type               char(1);   
   declare v_site_active            tinyint unsigned;
   declare v_site_system_status     int unsigned;
   
   declare v_msg                    varchar(255);
   declare v_rows, v_err            int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   
   
   
          
   select        type,        system_status,        active,   date_last_pms_file,   warn_no_upload_days,   warn_no_invite_days
     into  v_org_type, v_site_system_status, v_site_active, p_date_last_pms_file, p_warn_no_upload_days, p_warn_no_invite_days
   from   organisation
   where  orgid = p_orgid;
   if v_org_type != "S" then 
      leave stored_procedure; 
   end if;
   
   if exists ( select * 
               from   org_relation 
               where  c_orgid = p_orgid
               and    p_type   = "P"
               and    c_remote_ref is not null ) then
      set p_site_has_pms = 1;
   else
      set p_site_has_pms = 0;
   end if;
       
   select max(M.date_changed) into p_ab_max_date_changed
   from   ab_list_members M
   where  orgid = p_orgid;
   
   if @sp_debug = 1 then
      select  p_date_last_pms_file,  p_warn_no_upload_days, DATE_ADD(now(), INTERVAL - p_warn_no_upload_days DAY),
              p_ab_max_date_changed, p_warn_no_invite_days, DATE_ADD(now(), INTERVAL - p_warn_no_invite_days DAY)
              , v_site_system_status, v_site_active;
   end if;
   
   if ifnull(p_date_last_pms_file, now() ) > DATE_ADD(now(), INTERVAL - p_warn_no_upload_days DAY) then
      set p_date_last_pms_file = null, p_warn_no_upload_days = null;
   end if;
   
   if ifnull(p_ab_max_date_changed, now() )  > DATE_ADD(now(), INTERVAL - p_warn_no_invite_days DAY) then
      set p_ab_max_date_changed = null, p_warn_no_invite_days = null;
   end if;
   
   
   
   
   
   
   
   set v_last_year_start  = DATE_SUB( DATE_FORMAT(now(), '%Y-%m-01'), INTERVAL 1 YEAR),
       v_diff_month_start = DATE_SUB( DATE_FORMAT(now(), '%Y-%m-01'), INTERVAL 13 MONTH), 
       v_last_year_end    = DATE_FORMAT(now(), '%Y-%m-01'); 
   if @sp_debug = 1 then
      select v_last_year_start,  v_last_year_end, v_diff_month_start;
   end if;
   
   CREATE TEMPORARY TABLE t_email_stats ENGINE=MEMORY
      select 0 as month,
             sum(email_rows) as sum_email_rows,
             sum(total_rows) as sum_total_rows
      from   im_import
      where  orgid = p_orgid
      and    p_site_has_pms = 1
      and    status >= 1
      and    entry_time >= p_stats_start_time
      and    entry_time <= p_stats_end_time
   union all
      select TIMESTAMPDIFF( MONTH, v_diff_month_start, entry_time ) as month,
             sum(email_rows) as sum_email_rows,
             sum(total_rows) as sum_total_rows
      from   im_import
      where  orgid = p_orgid
      and    p_site_has_pms = 1
      and    status >= 1
      and    entry_time >= v_last_year_start
      and    entry_time <  v_last_year_end
      group by TIMESTAMPDIFF( MONTH, v_diff_month_start, entry_time );
      
   CREATE TEMPORARY TABLE t_rid_stats ENGINE=MEMORY
      select 0 as month,
             count(*) as  num_completed_rids
      from   rids R
      where  R.orgid = p_orgid
      and    R.remote_feed  = 1
      and    R.status       = 1
      and    R.date_started >= p_stats_start_time
      and    R.date_started <  p_stats_end_time
    union all
      select TIMESTAMPDIFF( MONTH, v_diff_month_start, R.date_started ) as month,
             count(*) as  num_completed_rids 
      from   rids R
      where  R.orgid = p_orgid
      and    R.remote_feed  = 1
      and    R.status       = 1
      and    R.date_started >= v_last_year_start
      and    R.date_started <  v_last_year_end
      group by TIMESTAMPDIFF( MONTH, v_diff_month_start, date_started );
      select "email_stats" as data_set, month, sum_email_rows, sum_total_rows,
             100*sum_email_rows / case sum_total_rows when 0 then null else sum_total_rows end as email_prcnt
      from   t_email_stats;
      select "rid_stats" as data_set, A.month, A.num_completed_rids, 
             null as num_total_rids, 
             100* A.num_completed_rids / case B.sum_email_rows when 0 then null else B.sum_email_rows end as rids_prcnt
      from   t_rid_stats   A,
             t_email_stats B
       where A.month = B.month;
      
      DROP TEMPORARY TABLE t_email_stats;
      DROP TEMPORARY TABLE t_rid_stats;
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `org_v1_import`( 
          IN  p_email     varchar(50),
          IN  p_stage     char(1), 
          OUT p_orgid     int unsigned
         )
stored_procedure:
begin
   declare v_import_count,
           v_orig_qnid,
           v_new_qnid,
           v_new_suid,
           v_uid,
           v_account_rid            int unsigned;
           
   declare v_first_id_key            bigint;
   declare v_msg                    varchar(255);
   declare v_rows, v_err            int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   set v_orig_qnid = 0, v_new_qnid =0 , p_orgid = null;
   select uid, account_rid, account_qnid into v_uid, v_account_rid, v_orig_qnid 
   from ImportDB.import_itx_user where email = p_email;
 
   set v_rows = ROW_COUNT();
   if v_rows != 1 then
      set @sp_return_stat = 1, v_msg = concat( 'org_v1_import: unknown email ', p_email);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;
   
if p_stage = "U" then
   if exists ( select * from users where email = p_email)  then
      set @sp_return_stat = 1, v_msg = concat( 'org_v1_import: user already exists', p_email);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;  
   
   select v_uid as uid, account_rid, cmp_company_name
   from ImportDB.import_itx_user A,
        ImportDB.import_reg_survey B
   where uid = v_uid
   and   account_rid = B.hdr_rid;
   insert into organisation
( type, active, system_status, name, tel, fax, address1, address2, postcode, city, province, country, 
no_of_rooms, star_grading, remote_ref, monthly_price, payment_method, payment_frequency, pricing_notes, 
questionnaire_instructions, reporting_instructions, report_recipients, hot_alert_details, 
send_invitation_delay_day, reminder_gap_days, notify_no_action_days, num_open_hot_alerts,
no_of_reminders,max_invitation_period_months, date_last_pms_file )
   SELECT
"S"   as type,
 0    as active, 
0 as system_status, 
est_name        as name, 
est_telephone as tel,
est_fac       as fax,
est_physical_address as address1, 
est_postal_address   as adrdess2,
null as postcode, null as city, null as province, null as country,
est_no_of_rooms        as no_of_rooms,
est_star_grading       as star_grading,
concat( "USE:", est_pms_account_number ) as remote_ref,
misc_agreed_monthly_pricing as monthly_price,
misc_payment_method    as payment_method,
misc_payment_frequency as payment_frequency,
misc_pricing_notes     as pricing_notes, 
misc_questionnaire_extra_instructions as questionnaire_instructions, 
misc_reporting_extra_instructions as reporting_instructions, 
misc_report_recipients as report_recipients,
misc_hot_alert_details as hot_alert_details,
ifnull( U.send_invitation_delay_day, 2) as send_invitation_delay_day,
ifnull( U.reminder_gap_days, 2 )    as reminder_gap_days, 
2 as notify_no_action_days,
0 as num_open_hot_alerts ,
ifnull(U.no_reminders, 1) as no_of_reminders,
ifnull(U.max_invitation_period_months,2) as max_invitation_period_months,
        concat(substring( account_cust_last_pms_file,7,4),'-',
               substring( account_cust_last_pms_file,4,2),'-',
               substring( account_cust_last_pms_file,1,2),' ',
               substring( account_cust_last_pms_file,12,5)) as date_last_pms_file2
   from ImportDB.import_itx_user U,
        ImportDB.import_reg_survey S
   where U.uid = v_uid
   and   U.account_rid = v_account_rid
   and   S.hdr_rid = v_account_rid;
   SET p_orgid = LAST_INSERT_ID(), v_rows = ROW_COUNT(), v_import_count = 1;
   insert ImportDB.import_log_org_build ( uid, reg_rid, orig_qnid, new_qnid, new_orgid, add_date, num_rows, import_count, table_name)
          values ( v_uid, v_account_rid, v_orig_qnid, v_new_qnid, p_orgid, now(), v_rows, v_import_count, "organisation" );
   insert ImportDB.key_migrate(syb_tab, mysql_tab, syb_id, mysql_id) values (  "users", "organisation", v_uid, p_orgid );
   insert ha_note_statuses ( orgid, name, active, is_initial_state )
         select p_orgid, S.name, S.active, S.is_initial_state
         from   ha_note_statuses S
         where  S.orgid  = 1
         and    S.active = 1;
   SET v_rows = ROW_COUNT(), v_import_count= ROW_COUNT();
   insert ImportDB.import_log_org_build ( uid, reg_rid, orig_qnid, new_qnid, new_orgid, add_date, num_rows, import_count, table_name)
          values ( v_uid, v_account_rid, v_orig_qnid, v_new_qnid, p_orgid, now(), v_rows, v_import_count, "ha_note_statuses" );
          
   INSERT INTO org_hierarchy(orgid, parent_orgid) 
      select p_orgid, G.orgid
      from  ImportDB.import_itx_user U
            INNER JOIN ImportDB.import_reg_survey   S ON U.account_rid = S.hdr_rid
            INNER JOIN organisation G ON S.est_pms_provider = G.name
      where U.uid = v_uid;
   SET v_rows = ROW_COUNT(), v_import_count= ROW_COUNT();
   insert ImportDB.import_log_org_build ( uid, reg_rid, orig_qnid, new_qnid, new_orgid, add_date, num_rows, import_count, table_name)
          values ( v_uid, v_account_rid, v_orig_qnid, v_new_qnid, p_orgid, now(), v_rows, v_import_count, "org_hierarchy" );
          
   insert org_langs( lngid, orgid, use_as_default )
      select (select lngid from language where name = "English") as lngid , 
             p_orgid, 
             1 as use_as_default;
   
   
   
   
   insert into users ( orgid, lngid, active, username, 
          password, contact_type, first_name, last_name, position, email, tel, fax, mobile )
   select  
      p_orgid ,
      39 as lngid, 1 as active,
      concat("MAIN_", p_orgid  )     as username, 
      
      main_password as password,
      "main"        as contact_type,
      substring_index( main_name, " ", 1 ) as first_name,
      substring(main_name FROM locate(" ",main_name) ) as last_name, 
      main_position as position, 
      main_email    as email, 
      main_tel      as tel, 
      main_fax      as fax, 
      main_mobile   as mobile
    from ImportDB.import_reg_survey    S
    where hdr_rid = v_account_rid;
    
   
   
   insert into users (orgid, lngid, active,  username, 
          password, contact_type, first_name, last_name, position, email, tel, fax, mobile )
   select 
      p_orgid, 
      39 as lngid, 1 as active, 
      concat("ACC_",p_orgid, FLOOR( (RAND() * 20)) )     as username, 
      UPPER(CONVERT(SUBSTRING(
        REPLACE(
          REPLACE(
            REPLACE(
              REPLACE(
                REPLACE(
                  REPLACE(
                    REPLACE(
                      MD5(RAND())
                    ,'1','')
                  ,'0','')
                ,'a','')
              ,'e','')
            ,'i','')
          ,'o','')
        ,'u','')
      FROM 1 FOR 6) USING latin1)) as password,
      "acc"         as contact_type,
      substring_index( acc_name, " ", 1 ) as first_name,
      substring(acc_name FROM locate(" ",acc_name) ) as last_name, 
      acc_position  as position, 
      acc_email     as email, 
      acc_tel       as tel, 
      acc_fax       as fax, 
      acc_mobile    as mobile
   from ImportDB.import_reg_survey    S
   where hdr_rid = v_account_rid
   and   not acc_name is null
   and   acc_email not in ( select email from users where orgid = p_orgid);
   
   
   
   insert into users (orgid, lngid, active,  username, 
      password, contact_type, first_name, last_name, position, email, tel, fax, mobile )
   select 
      p_orgid,
      39 as lngid, 1 as active, 
      concat("IT_", p_orgid, FLOOR( (RAND() * 20)))     as username, 
      UPPER(CONVERT(SUBSTRING(
        REPLACE(
          REPLACE(
            REPLACE(
              REPLACE(
                REPLACE(
                  REPLACE(
                    REPLACE(
                      MD5(RAND())
                    ,'1','')
                  ,'0','')
                ,'a','')
              ,'e','')
            ,'i','')
          ,'o','')
        ,'u','')
      FROM 1 FOR 6) USING latin1)) as password,
      "it"           as contact_type,
      substring_index( est_it_contact, " ", 1 ) as first_name,
      substring(est_it_contact FROM locate(" ",est_it_contact) ) as last_name, 
      null   as position, 
      concat( "IT@", p_orgid, ".tbd" )  as email, 
      null   as tel, 
      null   as fax, 
      null   as mobile
    from ImportDB.import_reg_survey    S
    where hdr_rid = v_account_rid
    and   char_length(est_it_contact) > 3;
   
   insert user_urole ( urid, uid)
      select (select urid from urole where name = "site") as urid, 
             uid  
      from users
      where orgid = p_orgid;
   SET v_rows = ROW_COUNT(), v_import_count= ROW_COUNT();
   insert ImportDB.import_log_org_build ( uid, reg_rid, orig_qnid, new_qnid, new_orgid, add_date, num_rows, import_count, table_name)
          values ( v_uid, v_account_rid, v_orig_qnid, v_new_qnid, p_orgid, now(), v_rows, v_import_count, "user_urole" );
          
   insert email_template( orgid, lngid, name, html_email, subject, body, 
          envelope_sender_name, envelope_sender_email, intro_msg_via_link )
   select  
          p_orgid as orgid, 
          39 as lngid, T.name, html_email, subject, body, ifnull(envelope_sender_name,""), 
          envelope_sender_email, "To take survey in English please click [#SURVEYLINK#]" as intro_msg_via_link 
   from   ImportDB.import_email_template T
   where  T.uid = v_uid;
   SET v_rows = ROW_COUNT(), v_import_count= ROW_COUNT();
   insert ImportDB.import_log_org_build ( uid, reg_rid, orig_qnid, new_qnid, new_orgid, add_date, num_rows, import_count, table_name)
          values ( v_uid, v_account_rid, v_orig_qnid, v_new_qnid, p_orgid, now(), v_rows, v_import_count, "email_template" );
  
   insert blocked_emails(orgid, email) 
      select distinct p_orgid, email 
      from  ImportDB.import_blocked_emails 
      where uid = v_uid;
      
   SET v_rows = ROW_COUNT(), v_import_count= ROW_COUNT();
   insert ImportDB.import_log_org_build ( uid, reg_rid, orig_qnid, new_qnid, new_orgid, add_date, num_rows, import_count, table_name)
          values ( v_uid, v_account_rid, v_orig_qnid, v_new_qnid, p_orgid, now(), v_rows, v_import_count, "blocked_emails" );
   leave stored_procedure;
 end if; 
  
   if p_orgid is null then
      select orgid into p_orgid
      from users
      where   email = p_email;
      set v_rows = ROW_COUNT();
      if v_rows != 1 then
         set @sp_return_stat = 1, v_msg = concat( 'org_v1_import: unknown email to determine org', p_email);
         SIGNAL SQLSTATE '01000'
         SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
         leave stored_procedure; 
      end if;
   end if;
if p_stage = "S" then 
  
   if exists ( select * 
               from   survey_used
               where  survey_provider = "SurveyShack"
               and    orgid = p_orgid ) then
      set @sp_return_stat = 1, v_msg = concat( 'org_v1_import: v1 survey already installed for orgid= ', p_orgid );
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;
      
   
   
   
 
 
insert questionnaire( orig_qnid, title,  type, active, created, last_updated )
   SELECT distinct orig_qnid, Stitle, "Standard Survey", 1, 
           case ifnull(CHAR_LENGTH(ltrim(Screated)),0) when 0 then null ELSE
                concat(substring( Screated,7,4),'-',
               substring( Screated,4,2),'-',
               substring( Screated,1,2),' ',
               substring( Screated,12,5)) END as created,
           case ifnull(CHAR_LENGTH(ltrim(Screated)),0) when 0 then null ELSE
                concat(substring( Screated,7,4),'-',
               substring( Screated,4,2),'-',
               substring( Screated,1,2),' ',
               substring( Screated,12,5)) END as created
   
   
   
   FROM ImportDB.import_survey_struct
   where orig_qnid = v_orig_qnid;
   
   SET v_new_qnid = LAST_INSERT_ID(), v_rows = ROW_COUNT();
   
insert page ( qnid, orig_pid, title, active, order_seq )
   SELECT distinct v_new_qnid, orig_pid, Ptitle, 1, Porder_seq
   FROM ImportDB.import_survey_struct I
   where I.orig_qnid = v_orig_qnid
   order by Porder_seq;
   SET v_rows = ROW_COUNT();
   select count( distinct orig_pid) into v_import_count FROM ImportDB.import_survey_struct where orig_qnid = v_orig_qnid;
   insert ImportDB.import_log_org_build ( uid, reg_rid, orig_qnid, new_qnid, new_orgid, add_date, num_rows, import_count, table_name)
          values ( v_uid, v_account_rid, v_orig_qnid, v_new_qnid, p_orgid, now(), v_rows, v_import_count, "page" );
          
insert question ( pid, qtypeid, txt_validation, orig_qid, active, order_seq, title, short_name, param_name)
   select  distinct         
           P.pid, QT.qtypeid, I.txt_validation, I.orig_qid, 1 as active, 
           Qorder_seq as order_seq, 
           Qtitle,  
           null as short_name, I.rtype_name  
   FROM ImportDB.import_survey_struct I,
        page P,
        qtype QT
   where I.orig_pid  = P.orig_pid
   and   P.qnid      = v_new_qnid
   and   I.orig_qnid = v_orig_qnid
   and   I.qtype = QT.title
   order by Porder_seq,Qorder_seq;
   
   SET v_rows = ROW_COUNT();
   select count( distinct orig_qid) into v_import_count FROM ImportDB.import_survey_struct where orig_qnid = v_orig_qnid;
   insert ImportDB.import_log_org_build ( uid, reg_rid, orig_qnid, new_qnid, new_orgid, add_date, num_rows, import_count, table_name)
          values ( v_uid, v_account_rid, v_orig_qnid, v_new_qnid, p_orgid, now(), v_rows, v_import_count, "question" );  
insert element( qid, orig_eid, name, dimension, order_seq, type, active )
   SELECT  N.qid, I.orig_eid, 
   ifnull(Ename,""),
   dimension, Eorder_seq, Etype, 1 as active 
   FROM ImportDB.import_survey_struct I,
        question N,
        page P
   where I.orig_pid  = P.orig_pid
   and   I.orig_qnid = v_orig_qnid
   and   I.orig_qid  = N.orig_qid
   and   P.qnid      = v_new_qnid
   and   P.pid       = N.pid
   order by Porder_seq,Qorder_seq,dimension,Eorder_seq;
   SET v_rows = ROW_COUNT();
   
   select count( distinct orig_eid) into v_import_count FROM ImportDB.import_survey_struct where orig_qnid = v_orig_qnid;
   
   insert ImportDB.import_log_org_build ( uid, reg_rid, orig_qnid, new_qnid, new_orgid, add_date, num_rows, import_count, table_name)
          values ( v_uid, v_account_rid, v_orig_qnid, v_new_qnid, p_orgid, now(), v_rows, v_import_count, "element" ); 
   insert qn_languages(qnid, lngid) 
      select v_new_qnid, (select lngid from language where name = "English") as lngid;
      
   call rslt_gen_survey_rpats( v_new_qnid );
insert into survey_used( survey_provider, survey_ref, orgid, active, date_start, date_end, qnid )
   select 
   "SurveyShack" as survey_provider,
   concat( "qnid = ", misc_qnid ) as survey_ref, 
   p_orgid, 
   1 as active, 
   Q.created as date_start,
   now() as date_end, 
   Q.qnid as qnid
    from ImportDB.import_itx_user   U,
         ImportDB.import_reg_survey S,
         questionnaire Q
   where U.uid  = v_uid
   and   U.account_rid = S.hdr_rid
   and   Q.qnid = v_new_qnid;
   SET v_new_suid = LAST_INSERT_ID(), v_rows = ROW_COUNT();
   call qn_rtype_auto_configure (v_new_qnid );
   leave stored_procedure;
end if;
   
   
   
if p_stage = "D" then
  
   if not ( select count(*) 
                from   survey_used
                where  survey_provider = "SurveyShack"
                and    orgid = p_orgid 
                and    date_end is not null) = 1 then
      set @sp_return_stat = 1, v_msg = concat( 'org_v1_import: Cannot find single survey already installed for orgid= ', p_orgid );
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;
   
   
   select qnid, suid into v_new_qnid, v_new_suid
   from   survey_used
   where  survey_provider = "SurveyShack"
   and    orgid = p_orgid
   and    date_end is not null limit 1;
insert ab_emails ( orgid, suid, create_date, proc_date, run_date, 
       date_sent, status, num_fail_receipients, num_success_receipients, 
       num_of_reminders, days_between_reminders, prepare_auto_remind, skip_notify )    
SELECT 
       p_orgid, 
       v_new_suid, 
       case ifnull(CHAR_LENGTH(ltrim(create_date)),0) when 0 then null ELSE
               concat(substring( create_date,7,4),'-',
               substring( create_date,4,2),'-',
               substring( create_date,1,2),' ',
               substring( create_date,12,5)) END as create_date,
       case ifnull(CHAR_LENGTH(ltrim(proc_date)),0) when 0 then null ELSE
               concat(substring( proc_date,7,4),'-',
               substring( proc_date,4,2),'-',
               substring( proc_date,1,2),' ',
               substring( proc_date,12,5)) END as proc_date,
       case ifnull(CHAR_LENGTH(ltrim(run_date)),0) when 0 then null ELSE
               concat(substring( run_date,7,4),'-',
               substring( run_date,4,2),'-',
               substring( run_date,1,2),' ',
               substring( run_date,12,5)) END as run_date, 
       case ifnull(CHAR_LENGTH(ltrim(date_sent)),0) when 0 then null ELSE
                concat(substring( date_sent,7,4),'-',
               substring( date_sent,4,2),'-',
               substring( date_sent,1,2),' ',
               substring( date_sent,12,5)) END as date_sent,
       "NOT SENT" as status, num_fail_receipients, num_success_receipients, 
       0 as num_of_reminders, days_between_reminders, prepare_auto_remind, skip_notify 
from ImportDB.import_ab_emails  T
where T.qnid = v_orig_qnid
order by T.ab_emid;
SET v_first_id_key = LAST_INSERT_ID(), v_rows = ROW_COUNT();
select count(*) into v_import_count FROM ImportDB.import_ab_emails where qnid = v_orig_qnid;
insert ImportDB.import_log_org_build ( uid, reg_rid, orig_qnid, new_qnid, new_orgid, add_date, num_rows, import_count, table_name)
          values ( v_uid, v_account_rid, v_orig_qnid, v_new_qnid, p_orgid, now(), v_rows, v_import_count, "ab_emails" ); 
insert into ImportDB.key_migrate ( syb_tab, mysql_tab, syb_id )
   select "ab_emails" as syb_tab, "ab_emails" as mysql_tab, T.ab_emid
from ImportDB.import_ab_emails  T
where T.qnid = v_orig_qnid
order by T.ab_emid;
set @first_seq_key = 1 + (select max(seq  ) from ImportDB.key_migrate ) - v_rows;
set @first_tab_key =     v_first_id_key;
update ImportDB.key_migrate
set    mysql_id = @first_tab_key + seq - @first_seq_key
where  mysql_tab = "ab_emails"
and    seq >= @first_seq_key;
insert ab_list_members(  orgid, release_date, latest_status, latest_date, latest_ab_emid, active, email, 
        first_name, last_name,invite_name, nationality, total_accommodation_charges, no_of_visits, 
        no_of_people, business_source, reservation_type, arrival_data, 
        date_of_birth, booking_ref, departure_date, date_changed ) 
   select 
        p_orgid, 
        concat(substring( release_date,7,4),'-',
               substring( release_date,4,2),'-',
               substring( release_date,1,2),' ',
               substring( release_date,12,5)) as release_date, 
        "NOT SENT" as latest_status, 
        concat(substring( status_date,7,4),'-',
               substring( status_date,4,2),'-',
               substring( status_date,1,2),' ',
               substring( status_date,12,5)) as latest_date, 
        get_new_key ( "ab_emails", "ab_emails", T.ab_emid )  as latest_ab_emid,
        T.active, email, 
        first_name, last_name,invite_name, nationality, total_accommodation_charges, no_of_visits, 
        no_of_people, business_source, reservation_type, arrival_data, 
        date_of_birth, booking_ref, departure_date,
        case ifnull(CHAR_LENGTH(ltrim(date_changed)),0) when 0 then null ELSE
                concat(substring( date_changed,7,4),'-',
               substring( date_changed,4,2),'-',
               substring( date_changed,1,2),' ',
               substring( date_changed,12,5)) END as date_changed
   from ImportDB.import_list_members T
   where T.uid  = v_uid
   order by T.ab_eid;
   SET v_first_id_key = LAST_INSERT_ID(), v_rows = ROW_COUNT();
select count(*) into v_import_count FROM ImportDB.import_list_members where uid  = v_uid;
   insert ImportDB.import_log_org_build ( uid, reg_rid, orig_qnid, new_qnid, new_orgid, add_date, num_rows, import_count, table_name)
          values ( v_uid, v_account_rid, v_orig_qnid, v_new_qnid, p_orgid, now(), v_rows, v_import_count, "ab_list_members" ); 
insert into ImportDB.key_migrate ( syb_tab, mysql_tab, syb_id )
   select "ab_list_members" as syb_tab, "ab_list_members" as mysql_tab, T.ab_eid
   from ImportDB.import_list_members T
   where T.uid = v_uid
   order by ab_eid; 
set @first_seq_key = 1 + (select max(seq  ) from ImportDB.key_migrate ) - v_rows;
set @first_tab_key =     v_first_id_key;
update ImportDB.key_migrate
set    mysql_id = @first_tab_key + seq - @first_seq_key
where  mysql_tab = "ab_list_members"
and    seq >= @first_seq_key;
SET @TRIGGER_CHECKS = FALSE; 
insert ab_email_recipients (ab_emid, ab_eid, email, status, remind)
   select EMID.mysql_id, EID.mysql_id,
          email, "NOT SENT" as status, 0 as remind 
   from ImportDB.import_ab_emails M,
        ImportDB.import_email_recipients A,
        ImportDB.key_migrate  EMID,
        ImportDB.key_migrate  EID
   where M.qnid       = v_orig_qnid
   and   M.ab_emid    = A.ab_emid
   and   EMID.syb_tab = "ab_emails"
   and   EID.syb_tab  = "ab_list_members"
   and   EMID.syb_id  = M.ab_emid
   and   EID.syb_id   = A.ab_eid
   order by A.ab_emid, A.ab_eid;
   SET v_rows = ROW_COUNT();
   select count(*) into v_import_count
   from  ImportDB.import_ab_emails A,
         ImportDB.import_email_recipients B
   where A.qnid    = v_orig_qnid
   and   A.ab_emid = B.ab_emid;
   insert ImportDB.import_log_org_build ( uid, reg_rid, orig_qnid, new_qnid, new_orgid, add_date, num_rows, import_count, table_name)
          values ( v_uid, v_account_rid, v_orig_qnid, v_new_qnid, p_orgid, now(), v_rows, v_import_count, "ab_email_recipients" ); 
          
SET @TRIGGER_CHECKS = TRUE;
insert links( orgid, source, link_type, link, suid, ab_emid, ab_eid, lngid)
   select   p_orgid, "L" as source, link_type, L.link, v_new_suid, 
   EMID.mysql_id as ab_emid, 
   EID.mysql_id  as ab_eid,
   39 as lngid
   from  ImportDB.import_links L,
         ImportDB.key_migrate  EMID,
         ImportDB.key_migrate  EID
   where L.link_type  = "abk"
   and   L.qnid =  v_orig_qnid
   and   EMID.syb_tab = "ab_emails"
   and   EID.syb_tab  = "ab_list_members"
   and   EMID.syb_id  = L.ab_emid
   and   EID.syb_id   = L.ab_eid
   order by L.lid;
   SET v_rows = ROW_COUNT();
   select count(*) into v_import_count FROM ImportDB.import_links where link_type = "abk" and qnid = v_orig_qnid ;
   insert ImportDB.import_log_org_build ( uid, reg_rid, orig_qnid, new_qnid, new_orgid, add_date, num_rows, import_count, table_name)
          values ( v_uid, v_account_rid, v_orig_qnid, v_new_qnid, p_orgid, now(), v_rows, v_import_count, "links(ab)" ); 
          
insert links( link_type, link, orgid, suid, source, lngid )
   select L.link_type, L.link, p_orgid , v_new_suid, "R" as source, 39 as lngid
   from ImportDB.import_links L
   where L.link_type in (  "man", "clp")
   and   L.qnid =  v_orig_qnid
   order by L.lid;
   SET v_rows = ROW_COUNT();
   select count(*) into v_import_count FROM ImportDB.import_links where link_type in ("man", "clp") and qnid = v_orig_qnid ;
   
   insert ImportDB.import_log_org_build ( uid, reg_rid, orig_qnid, new_qnid, new_orgid, add_date, num_rows, import_count, table_name)
          values ( v_uid, v_account_rid, v_orig_qnid, v_new_qnid, p_orgid, now(), v_rows, v_import_count, "links(main)" ); 
insert ImportDB.import_rpatid_map ( qnid, rpatid, new_rpatid )
   select Z.qnid, I.rpatid, RP.rpatid
from   questionnaire Z
       inner join page P
          on  Z.qnid  = v_new_qnid
          and P.qnid = v_new_qnid 
       inner join question Q
          on P.pid  = Q.pid     
       inner join respattern RP
          on Q.qid = RP.qid
       inner join element E1
          on RP.eid1 = E1.eid
       left outer join element E2  
          on RP.eid2 = E2.eid
       left outer join ImportDB.import_old_rpatid I
          on Z.orig_qnid = I.qnid
          and E1.orig_eid = I.eid1
          and( E2.orig_eid = I.eid2 or I.eid2 = 0 );
   SET v_rows = ROW_COUNT(), v_import_count = ROW_COUNT();
   insert ImportDB.import_log_org_build ( uid, reg_rid, orig_qnid, new_qnid, new_orgid, add_date, num_rows, import_count, table_name)
          values ( v_uid, v_account_rid, v_orig_qnid, v_new_qnid, p_orgid, now(), v_rows, v_import_count, "import_rpatid_map" ); 
insert rids ( orig_rid, qnid, orgid, lngid, date_started, last_update, status, ab_rcpid, email, name )
   select distinct orig_rid, 
          v_new_qnid, p_orgid,
          39 as lngid, 
          concat(substring( date_started,7,4),'-',
               substring( date_started,4,2),'-',
               substring( date_started,1,2),' ',
               substring( date_started,12,5)) as date_started, 
          concat(substring( last_update,7,4),'-',
               substring( last_update,4,2),'-',
               substring( last_update,1,2),' ',
               substring( last_update,12,5)) as last_update, 
          R.status,
          S.ab_rcpid,
          R.email, R.name
   from ImportDB.import_survey_result R,
        ImportDB.key_migrate  EMID,
        ImportDB.key_migrate  EID,
        ab_email_recipients   S
   where R.orig_qnid = v_orig_qnid
   and   R.ab_emid > 0
   and   EMID.syb_tab = "ab_emails"
   and   EID.syb_tab  = "ab_list_members"
   and   EMID.syb_id  = R.ab_emid
   and   EID.syb_id   = R.ab_eid
   and   S.ab_emid =  EMID.mysql_id 
   and   S.ab_eid  =  EID.mysql_id;
   SET v_rows = ROW_COUNT();
   select count( distinct orig_rid ) into v_import_count FROM ImportDB.import_survey_result 
   where orig_qnid = v_orig_qnid and ab_emid > 0;
   insert ImportDB.import_log_org_build ( uid, reg_rid, orig_qnid, new_qnid, new_orgid, add_date, num_rows, import_count, table_name)
          values ( v_uid, v_account_rid, v_orig_qnid, v_new_qnid, p_orgid, now(), v_rows, v_import_count, "rids(ab)" );
insert rids ( orig_rid, qnid, orgid, lngid, date_started, last_update, status,  email, name )
   select distinct orig_rid, 
          v_new_qnid, p_orgid,
          39 as lngid, 
          concat(substring( date_started,7,4),'-',
               substring( date_started,4,2),'-',
               substring( date_started,1,2),' ',
               substring( date_started,12,5)) as date_started, 
          concat(substring( last_update,7,4),'-',
               substring( last_update,4,2),'-',
               substring( last_update,1,2),' ',
               substring( last_update,12,5)) as last_update, 
          R.status,
          
          R.email, R.name
   from ImportDB.import_survey_result R
   where R.orig_qnid = v_orig_qnid
   and   R.ab_emid is null;
   SET v_rows = ROW_COUNT();
   select count( distinct orig_rid ) into v_import_count FROM ImportDB.import_survey_result 
   where orig_qnid = v_orig_qnid and ab_emid is null;
   
   insert ImportDB.import_log_org_build ( uid, reg_rid, orig_qnid, new_qnid, new_orgid, add_date, num_rows, import_count, table_name)
          values ( v_uid, v_account_rid, v_orig_qnid, v_new_qnid, p_orgid, now(), v_rows, v_import_count, "rids(main)" );
insert result (rid, rpatid )
 SELECT R.rid, M.new_rpatid
   FROM ImportDB.import_survey_result I
        , rids R
        , ImportDB.import_rpatid_map M
   where I.orig_qnid = v_orig_qnid
   and   R.qnid      = v_new_qnid
   and   R.orig_rid  = I.orig_rid
   and   I.rpatid    = M.rpatid;
   SET v_rows = ROW_COUNT();
   select count(*) into v_import_count FROM ImportDB.import_survey_result 
   where orig_qnid = v_orig_qnid ;
   
   insert ImportDB.import_log_org_build ( uid, reg_rid, orig_qnid, new_qnid, new_orgid, add_date, num_rows, import_count, table_name)
          values ( v_uid, v_account_rid, v_orig_qnid, v_new_qnid, p_orgid, now(), v_rows, v_import_count, "result" );
insert result_detail (rid, rpatid, str, num, numf)
 SELECT R.rid, M.new_rpatid, str, num, numf
   FROM ImportDB.import_survey_result I,
        ImportDB.import_rpatid_map M,
        rids R
   where I.orig_qnid = v_orig_qnid
   and   R.qnid      = v_new_qnid
   and   R.orig_rid = I.orig_rid
   and ( str is not null or  num is not null or numf is not null)
   and   I.rpatid = M.rpatid;
   SET v_rows = ROW_COUNT();
   
   select count(*) into v_import_count FROM ImportDB.import_survey_result 
   where orig_qnid = v_orig_qnid and ( str is not null or  num is not null or numf is not null);
   
   insert ImportDB.import_log_org_build ( uid, reg_rid, orig_qnid, new_qnid, new_orgid, add_date, num_rows, import_count, table_name)
          values ( v_uid, v_account_rid, v_orig_qnid, v_new_qnid, p_orgid, now(), v_rows, v_import_count, "result_detail" );
insert im_import(orgid, entry_time, filename, status, total_rows, email_rows)
   select p_orgid, concat(substring( entry_time,7,4),'-',
                 substring( entry_time,4,2),'-',
                 substring( entry_time,1,2),' ',
                 substring( entry_time,12,5)) as entry_time2,
          filename, status, total_rows, email_rows 
   from   ImportDB.import_im_import I
   where  uid = v_uid;
   SET v_rows = ROW_COUNT(), v_import_count = ROW_COUNT();
   
   insert ImportDB.import_log_org_build ( uid, reg_rid, orig_qnid, new_qnid, new_orgid, add_date, num_rows, import_count, table_name)
          values ( v_uid, v_account_rid, v_orig_qnid, v_new_qnid, p_orgid, now(), v_rows, v_import_count, "im_import" );
   
   update rids A,
          ab_email_recipients B,
          ab_list_members M
   set    remote_feed = 1
   where A.orgid = p_orgid
   and   A.ab_rcpid = B.ab_rcpid
   and   B.ab_eid   = M.ab_eid
   and   ( sign(ascii(M.business_source)) = 1 or sign(ascii(M.booking_ref))  );
end if;
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `org_wipeout`( IN p_orgid          integer unsigned
         )
stored_procedure:
begin
   declare v_qnid         integer unsigned;
   declare v_qtypeid      integer unsigned;
   declare v_msg          varchar(255);
   declare v_rows, v_err  int default 0;
   
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   if not exists( select orgid from organisation where orgid = p_orgid ) then
      set @sp_return_stat = 1, v_msg = concat( 'org_wipeout: not found orgid ', p_orgid);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;
   
   
   if exists( select *
              from   report where orgid = p_orgid)
       or exists( select *
                  from   survey_used where orgid = p_orgid)
   then
      select distinct concat( "call rpt_report_wipeout ( ", rpid, ");" ) as abort_must_call_sp
      from   report where orgid = p_orgid
      union all 
      select distinct concat( "call qn_questionaire_wipeout ( ", qnid, ");" ) as abort_must_call_sp
      from   survey_used where orgid = p_orgid;
      
      leave stored_procedure;   
   end if;
   
   
   delete from im_import            where orgid    = p_orgid;
   delete from links                where orgid    = p_orgid;   
 
   
   delete r
   from   ab_list_members   m,
          ImportDB.key_migrate r
   where  m.orgid     = p_orgid
   and    r.mysql_tab = "ab_list_members"
   and    m.ab_eid    = r.mysql_id;
   
   delete B
   from ab_list_members A,
        ab_list_member_audit B
   where A.ab_eid = B.ab_eid
   and   A.orgid  = p_orgid;
   
   delete from ab_list_members       where orgid    = p_orgid;
   delete from no_de_dupe_emails     where orgid    = p_orgid;  
   delete from blocked_emails        where orgid    = p_orgid;
   delete from email_template        where orgid    = p_orgid;
   delete from user_urole where uid in (select uid from users where orgid = p_orgid);
   delete DEL
   from   users u,
          user_new_ha_notify DEL
   where  u.uid   = DEL.uid
   and    u.orgid = p_orgid;
   
   delete DEL
   from   users u,
          user_session DEL
   where  u.uid   = DEL.uid
   and    u.orgid = p_orgid;
   
   delete from users                 where orgid    = p_orgid;
   delete from org_langs             where orgid    = p_orgid;
   
   delete from org_hierarchy         where orgid    = p_orgid;
   delete from org_hierarchy         where parent_orgid = p_orgid;
   delete from ha_note_statuses      where orgid    = p_orgid;
   delete from ImportDB.key_migrate  where mysql_id = p_orgid and mysql_tab =  "organisation" ;
   delete from organisation          where orgid    = p_orgid;
   
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `org_wipeout_all_activity`( IN p_orgid          integer unsigned
         )
stored_procedure:
begin
   declare v_qtypeid integer unsigned;
   declare v_rows, v_err  int default 0;
   declare v_msg          varchar(255);
   
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   if not exists( select orgid from organisation where orgid = p_orgid ) then
      set @sp_return_stat = 1, v_msg = concat( 'org_wipeout_all_activity: not found orgid ', p_orgid);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;
   
   
   
   
   
   delete DEL
   from   rids  r,
          hot_alert a,
          hot_alert_read_monitor DEL,
          survey_used U
   where  U.orgid = p_orgid
   and    U.qnid = r.qnid
   and    r.rid  = a.rid
   and    a.haid = DEL.haid ;  
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "hot_alert_read_monitor deleted rows = ", v_rows; end if;  
   delete DEL
   from   rids  r,
          hot_alert a,
          hot_alert_note DEL,
          survey_used U
   where  U.orgid = p_orgid
   and    U.qnid = r.qnid
   and    r.rid  = a.rid
   and    a.haid = DEL.haid ;  
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "hot_alert_note deleted rows = ", v_rows; end if;  
   delete DEL
   from   rids  r,
          hot_alert a,
          hot_alert_recipient DEL,
          survey_used U
   where  U.orgid = p_orgid
   and    U.qnid = r.qnid 
   and    r.rid  = a.rid
   and    a.haid = DEL.haid ;  
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "hot_alert_recipient deleted rows = ", v_rows; end if;  
   delete a
   from   rids  r,
          hot_alert a,
          survey_used U
   where  U.orgid = p_orgid
   and    U.qnid = r.qnid 
   and    r.rid  = a.rid ;  
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "hot_alert deleted rows = ", v_rows; end if;  
   
   
   
   
   delete l
   from   survey_used s,
          links  l
   where  s.orgid = p_orgid
   and    s.suid  = l.suid
   and    l.link_type in ( "abk", "irt" );
   
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "links deleted rows = ", v_rows; end if;
   delete r
   from   survey_used s,
          ab_emails   m,
          ab_email_recipients  r
   where  s.orgid   = p_orgid
   and    s.suid    = m.suid
   and    m.ab_emid = r.ab_emid;
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "ab_email_recipients deleted rows = ", v_rows; end if;
   delete r
   from   survey_used s,
          ab_emails   m,
          ImportDB.key_migrate r
   where  s.orgid    = p_orgid
   and    s.suid    = m.suid
   and    r.mysql_tab = "ab_emails"
   and    m.ab_emid   = r.mysql_id;
   
   set v_rows = ROW_COUNT(); 
   
   if @sp_debug = 1 then select "ab_emails - ImportDB.key_migrate deleted rows = ", v_rows; end if;
   delete m
   from   survey_used s,
          ab_emails   m
   where  s.orgid   = p_orgid
   and    s.suid    = m.suid;
   set v_rows = ROW_COUNT();
   
   if @sp_debug = 1 then select "ab_emails deleted rows = ", v_rows; end if;
   
 
   delete a
   from   result_variable_ans a,
          rids  r,
          survey_used U
   where  U.orgid = p_orgid
   and    U.qnid = r.qnid
   and    r.rid  = a.rid;
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "result_variable_ans deleted rows = ", v_rows; end if;
   
   delete a
   from   result_element_header a,
          rids  r,
          survey_used U
   where  U.orgid = p_orgid
   and    U.qnid = r.qnid
   and    r.rid  = a.rid;
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "result_element_header deleted rows = ", v_rows; end if;
   
   delete a
   from   result_detail a,
          rids  r,
          survey_used U
   where  U.orgid = p_orgid
   and    U.qnid = r.qnid
   and    r.rid  = a.rid;  
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "result_detail deleted rows = ", v_rows; end if;
   
   delete a
   from   result a,
          rids  r,
          survey_used U
   where  U.orgid = p_orgid
   and    U.qnid =  r.qnid
   and    r.rid  = a.rid;  
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "result deleted rows = ", v_rows; end if;
   
   delete r
   from   rids r,
          survey_used U
   where  U.orgid = p_orgid
   and    U.qnid  = r.qnid;
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "rids deleted rows = ", v_rows; end if;
   
   
   delete c
   from   im_import_content   c,
          im_import i
   where  i.orgid = p_orgid
   and    i.iid   = c.iid;
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "im_import_content deleted rows = ", v_rows; end if;
   
   delete from im_import            where orgid    = p_orgid;
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "im_import deleted rows = ", v_rows; end if;
   
   
   
   delete r
   from   ab_list_members   m,
          ImportDB.key_migrate r
   where  m.orgid     = p_orgid
   and    r.mysql_tab = "ab_list_members"
   and    m.ab_eid    = r.mysql_id;
   
   delete B
   from ab_list_members A,
        ab_list_member_audit B
   where A.ab_eid = B.ab_eid
   and   A.orgid  = p_orgid;
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "ab_list_member_audit deleted rows = ", v_rows; end if;
   
   delete from ab_list_members       where orgid    = p_orgid;
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "ab_list_members deleted rows = ", v_rows; end if;
   delete from no_de_dupe_emails     where orgid    = p_orgid;  
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "no_de_dupe_emails deleted rows = ", v_rows; end if;
   delete from blocked_emails        where orgid    = p_orgid;
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "blocked_emails deleted rows = ", v_rows; end if;
   
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `pms_add_to_ab`( 
          IN p_mode varchar(1), 
          IN p_orgid int unsigned,
          IN p_lngid int unsigned,
          IN p_release_date datetime,
          IN p_email varchar(60),
          IN p_first_name varchar(100),
          IN p_last_name varchar(100),
          IN p_nationality varchar(255),
          IN p_total_accommodation_charges varchar(255),
          IN p_no_of_visits varchar(255),
          IN p_no_of_people varchar(255),
          IN p_business_source varchar(255),
          IN p_reservation_type varchar(255),
          IN p_arrival_date varchar(255),
          IN p_date_of_birth varchar(255),
          IN p_booking_ref varchar(255),
          IN p_departure_date datetime
         )
stored_procedure:
begin
  
	declare vab_eid int unsigned default 0;
	declare vname varchar(255);
  
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;   
   set @sp_return_stat = 0;  
	
    if p_mode = "D" then
		insert into ab_list_members (orgid, lngid, release_date, active, email, first_name, last_name, invite_name, nationality, total_accommodation_charges, no_of_visits, no_of_people, business_source, reservation_type, arrival_data, date_of_birth, booking_ref, departure_date, data_source, latest_status, latest_date) values (p_orgid, p_lngid, p_release_date, 1, p_email, p_first_name, p_last_name, concat(p_first_name, " ", p_last_name), p_nationality, p_total_accommodation_charges, p_no_of_visits, p_no_of_people, p_business_source, p_reservation_type, p_arrival_date, p_date_of_birth, p_booking_ref, p_departure_date, "PMS", "NEW", now());
		select concat(p_first_name, p_last_name) into vname;
		if vname = "" then
			update ab_list_member set first_name = cast(LAST_INSERT_ID() as char), last_name = cast(LAST_INSERT_ID() as char), invite_name = "Guest" where ab_eid = LAST_INSERT_ID();
		end if;
	else 
		select ab_eid into vab_eid from ab_list_members where email = p_email and orgid = p_orgid;
		if vab_eid = 0 then
			insert into ab_list_members (orgid, lngid, release_date, active, email, first_name, last_name, invite_name, nationality, total_accommodation_charges, no_of_visits, no_of_people, business_source, reservation_type, arrival_data, date_of_birth, booking_ref, departure_date, data_source, latest_status, latest_date) values (p_orgid, p_lngid, p_release_date, 1, p_email, p_first_name, p_last_name, concat(p_first_name, " ", p_last_name), p_nationality, p_total_accommodation_charges, p_no_of_visits, p_no_of_people, p_business_source, p_reservation_type, p_arrival_date, p_date_of_birth, p_booking_ref, p_departure_date, "PMS", "NEW", now());
		else
			update ab_list_members set lngid = p_lngid, release_date = p_release_date, email = p_email, first_name = p_first_name, last_name = p_last_name, invite_name = concat(p_first_name, " ", p_last_name), nationality = p_nationality, total_accommodation_charges = p_total_accommodation_charges, no_of_visits = p_no_of_visits, no_of_people = p_no_of_people, business_source = p_business_source, reservation_type = p_reservation_type, arrival_data = p_arrival_date, date_of_birth = p_date_of_birth, booking_ref = p_booking_ref, departure_date = p_departure_date where ab_eid = vab_eid;
		end if; 
	end if;
end$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `pms_config_add_item`( IN p_pms_name           varchar(255),
          IN p_remote_feed_type   varchar(10),
          IN p_pms_attr_name      varchar(255),
          IN p_val_S              varchar(500),
          IN p_val_I              int unsigned
         )
stored_procedure:
begin
   declare v_orgid             integer unsigned;
   declare v_attr_id           integer unsigned;
   declare v_msg               varchar(255);   
   declare v_rows, v_err       int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   select orgid into v_orgid
   from   organisation
   where  name = p_pms_name;
   set v_rows = ROW_COUNT();
   
   if v_rows != 1 then
      set @sp_return_stat = 1, v_msg = concat( 'pms_config_add_item: unknown p_pms_name ', p_pms_name);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;
   
   
   if not exists ( select * FROM org_remote_feed  where orgid = v_orgid and type = p_remote_feed_type ) then
      set @sp_return_stat = 1, v_msg = concat( 'pms_config_add_item: unknown remote feed ', p_remote_feed_type);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;
   
   select attr_id into  v_attr_id
   from   cfg_attribute 
   where  name = p_pms_attr_name;
   set v_rows = ROW_COUNT();
   
   if v_rows != 1 then
      set @sp_return_stat = 1, v_msg = concat( 'pms_config_add_item: unknown p_pms_attr_name ', p_pms_attr_name);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;
 
   if exists( select * from org_remote_feed_attribute 
              where  orgid = v_orgid and type = p_remote_feed_type and attr_id = v_attr_id )
   then
      update org_remote_feed_attribute
      set    val_S = p_val_S, val_I = p_val_I 
      where  orgid   = v_orgid
      and    type    = p_remote_feed_type
      and    attr_id = v_attr_id;
      set v_rows = ROW_COUNT();
   else
      insert org_remote_feed_attribute ( orgid, type, attr_id, val_S, val_I )
         values ( v_orgid, p_remote_feed_type, v_attr_id,  p_val_S, p_val_I );
      set v_rows = ROW_COUNT();
   end if;
   if v_rows != 1 then
      set @sp_return_stat = 1, v_msg = concat( 'pms_config_add_item: config failed to update for', p_pms_attr_name);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;
   
   if @sp_debug = 1 then 
      select g.orgid, g.active, g.name as org_name, f.type, a.name, fa.val_S, fa.val_I 
      from   organisation    g,
             org_remote_feed f,
             org_remote_feed_attribute fa,
             cfg_attribute a
      where  g.orgid = v_orgid
      and    f.type  = p_remote_feed_type
      and    g.orgid    = f.orgid
      and    f.orgid    = fa.orgid
      and    f.type     = fa.type
      and    fa.attr_id = a.attr_id;
   end if;
   
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `qn_create_element`( 
          INOUT p_eid integer unsigned,
          IN    p_action      char(1),
          IN    p_qid integer unsigned,
          IN    p_type        varchar(255),
          IN    p_orig_eid    integer unsigned,
          IN    p_name        varchar(255),
          IN    p_dimension   tinyint unsigned,
          IN    p_order_seq   smallint unsigned,
          IN    p_active      tinyint unsigned,
          IN    p_name_alias  varchar(500)
         )
stored_procedure:
begin
  
	declare veid int unsigned default 0;
	declare vorder_seq int unsigned default 0;
  
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;   
   set @sp_return_stat = 0;
   
	if p_dimension > 2 then
		select e.eid, e.order_seq into veid, vorder_seq from element e where e.name = p_name and e.qid = p_qid;
	else
		select e.eid, e.order_seq into veid, vorder_seq from element e where e.orig_eid = p_orig_eid and e.qid = p_qid;
	end if;
	if veid = 0 then
		call qn_element_build(p_eid, "I", p_qid, p_type, p_orig_eid, p_name, p_dimension, p_order_seq, p_active, null, p_name_alias);
	else	
	    call qn_element_build(veid, "U", p_qid, p_type, p_orig_eid, p_name, p_dimension, p_order_seq, p_active, null,p_name_alias);
		set p_eid = veid;
	end if;
	select p_eid as eid;      
  
end$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `qn_create_page`( 
          INOUT p_eid    integer unsigned,
          IN p_qnid int  unsigned,
          IN p_orig_pid  int unsigned,
          IN p_title     varchar(500),
          IN p_order_seq int unsigned
         )
stored_procedure:
begin
  
	declare vpid int unsigned default 0;
	declare vorder_seq int unsigned default 0;
  
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;   
   set @sp_return_stat = 0;
   
	select p.pid, p.order_seq into vpid, vorder_seq from page p where p.orig_pid = p_orig_pid and p.qnid = p_qnid;
	if vpid = 0 then
		insert into page (qnid, orig_pid, title, active, order_seq) values (p_qnid, p_orig_pid, p_title, 1, p_order_seq);
		set vpid = LAST_INSERT_ID();
	else               
		if vorder_seq != p_order_seq then
			update page set title = p_title, order_seq = p_order_seq where pid = vpid;
		else
			update page set title = p_title where pid = vpid;
		end if;
	end if;
	select vpid as pid;  
  
end$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `qn_create_question`( 
          INOUT p_qid integer unsigned,
          IN p_action char(1),
          IN p_pid integer unsigned,
          IN p_qtype varchar(500),
          IN p_txt_validation char(1),
          IN p_orig_qid integer unsigned,
          IN p_active tinyint unsigned,
          IN p_order_seq smallint unsigned,
          IN p_title varchar(500),
          IN p_short_name varchar(255),
          IN p_param_name varchar(255)
         )
stored_procedure:
begin
  
	declare vqid int unsigned default 0;
	declare vorder_seq int unsigned default 0;
  
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;   
   set @sp_return_stat = 0;
   
	select q.qid, q.order_seq into vqid, vorder_seq from question q where q.orig_qid = p_orig_qid and q.pid = p_pid;
	if vqid = 0 then
		call qn_question_build(p_qid, "I", p_pid, p_qtype, p_txt_validation, p_orig_qid, p_active, p_order_seq, p_title, p_short_name, p_param_name);
	else               
		call qn_question_build(vqid, "U", p_pid, p_qtype, p_txt_validation, p_orig_qid, p_active, p_order_seq, p_title, p_short_name, p_param_name);
		set p_qid = vqid;
	end if;
	select p_qid as qid;       
end$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `qn_create_survey`( 
          INOUT p_qid integer unsigned,
          IN p_orig_qnid int unsigned,
          IN p_survey_provider varchar(255),
          IN p_title varchar(500),
          IN p_type varchar(255)
         )
stored_procedure:
begin
  
	declare vqnid int unsigned default 0;
  
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;   
   set @sp_return_stat = 0;  
	
	select q.qnid into vqnid from questionnaire q, survey_used u where q.orig_qnid = p_orig_qnid and q.qnid = u.qnid and u.survey_provider = p_survey_provider;
	if vqnid = 0 then
		insert into questionnaire (orig_qnid, title, type, active, created, last_updated) values (p_orig_qnid, p_title, p_type, 1, now(), now());
		set vqnid = LAST_INSERT_ID();
	else
		update questionnaire set title = p_title where qnid = vqnid;
	end if;
	update page p, question q, element e, qtype qq set e.active = 0 where p.qnid = vqnid and q.pid = p.pid and e.qid = q.qid and q.qtypeid = qq.qtypeid and qq.title not in ("essay", "parameter", "text");
	update page p, question q set q.active = 0 where p.qnid = vqnid and q.pid = p.pid;
	update page p set p.active = 0 where p.qnid = vqnid;
	
	select vqnid as qnid;
end$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `qn_create_survey_link`( 
        	IN p_language varchar(255),
        	IN p_orgid int unsigned,
        	IN p_link varchar(255),
         	IN p_suid int unsigned
         )
stored_procedure:
begin
  
	declare vlid, vlngid int unsigned default 0;
  
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;   
   set @sp_return_stat = 0;  
   
	select lngid into vlngid from language where name = p_language; 
	                          
	select lid into vlid from links where orgid = p_orgid and source = "R" and link_type = "man" and lngid = vlngid
  and suid  = p_suid;
	
  if @sp_debug = 1 then  select vlngid, vlid;  end if;
  
	if vlid > 0 then
		update links 
    set link = p_link 
    where orgid = p_orgid 
    and source = "R" 
    and link_type = "man" 
    and lngid = vlngid 
    and suid = p_suid; 
  else
  		insert ignore into links (orgid, source, link_type, link, suid, lngid) 
                        values (p_orgid, 'R', 'man', p_link, p_suid, vlngid); 
	end if;  
end$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `qn_element_build`( INOUT p_eid          integer unsigned,
          IN  p_action         char(1), 
          IN  p_qid            integer unsigned,
          IN  p_type           varchar(255),  
          IN  p_orig_eid       integer unsigned,
          
          IN  p_name           varchar(255),
          IN  p_dimension      tinyint unsigned,
          IN  p_order_seq      smallint unsigned,
          IN  p_active         tinyint unsigned,
          IN  p_score          integer,
          IN  p_name_alias     varchar(500)
         )
stored_procedure:
begin
   declare v_rows, v_err  int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   
   
   
   case p_action 
   when "U" then
   
      update element
      set qid       = p_qid,
          type      = p_type,
          orig_eid  = p_orig_eid,
          
          name      = p_name,
          dimension = p_dimension,
          order_seq = p_order_seq,
          active    = p_active,
          score     = p_score,
          name_alias = p_name_alias
      where eid = p_eid;
      set v_rows = ROW_COUNT();
      
      if v_rows != 1 then
         set @sp_return_stat = 1;
         SIGNAL SQLSTATE '01000'
         SET MESSAGE_TEXT = 'qn_element_build: update failed', MYSQL_ERRNO = 1000;
         leave stored_procedure;  
      end if;
   
   when "I" then
      insert element ( qid,   orig_eid,   name,   dimension,   order_seq,   type,   active,   score, name_alias ) 
              values ( p_qid, p_orig_eid, p_name, p_dimension, p_order_seq, p_type, p_active, p_score, p_name_alias);
      SET p_eid = LAST_INSERT_ID();
      
      if @sp_debug = 1 then
         select p_eid as p_eid;
      end if;
   else
      begin end; 
   end case;
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `qn_questionaire_disable`( IN p_qnid          integer unsigned
         )
stored_procedure:
begin
   declare v_qtypeid integer unsigned;
   declare v_rows, v_err  int default 0;
   
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   if not exists( select qnid from questionnaire where qnid = p_qnid ) then
      set @sp_return_stat = 1;
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = 'qn_questionaire_disable: unknown qnid', MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;  
   update organisation A,
          survey_used B
   set  A.remote_ref = null
   where B.qnid = p_qnid
   and   B.date_end is null
   and   B.orgid = A.orgid;
             
   update survey_used
   set    active = 0, date_end = now()
   where qnid = p_qnid
   and   date_end is null;
   
   update questionnaire
   set    orig_qnid =0, title = concat( "OLD ", qnid," ", title )
   where  qnid = p_qnid;
   select * from questionnaire where qnid = p_qnid;
   select * from survey_used   where qnid = p_qnid;
   
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `qn_questionaire_wipeout`( IN p_qnid          integer unsigned
         )
stored_procedure:
begin
   declare v_qtypeid integer unsigned;
   declare v_rows, v_err  int default 0;
   
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   if not exists( select qnid from questionnaire where qnid = p_qnid ) then
      set @sp_return_stat = 1;
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = 'qn_questionaire_wipeout: unknown qnid', MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;
   
   
   
   
   if exists( select *
              from   page      p,
                     question  q,
                     report_entry  re
              where  p.qnid = p_qnid
              and    p.pid  = q.pid
              and    q.qid  = re.qid)
   then
      select distinct concat( "call rpt_report_wipeout ( ", re.rpid, ");" ) as abort_must_call_sp
      from   page          p,
             question      q,
             report_entry  re
      where  p.qnid = p_qnid
      and    p.pid  = q.pid
      and    q.qid  = re.qid;
      
      leave stored_procedure;   
   end if;
   
   
   
   
   
   delete DEL
   from   rids  r,
          hot_alert a,
          hot_alert_read_monitor DEL 
   where  r.qnid = p_qnid
   and    r.rid  = a.rid
   and    a.haid = DEL.haid ;  
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "hot_alert_read_monitor deleted rows = ", v_rows; end if;  
   delete DEL
   from   rids  r,
          hot_alert a,
          hot_alert_note DEL 
   where  r.qnid = p_qnid
   and    r.rid  = a.rid
   and    a.haid = DEL.haid ;  
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "hot_alert_note deleted rows = ", v_rows; end if;  
   delete DEL
   from   rids  r,
          hot_alert a,
          hot_alert_recipient DEL 
   where  r.qnid = p_qnid
   and    r.rid  = a.rid
   and    a.haid = DEL.haid ;  
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "hot_alert_recipient deleted rows = ", v_rows; end if;  
   delete a
   from   rids  r,
          hot_alert a
   where  r.qnid = p_qnid
   and    r.rid  = a.rid ;  
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "hot_alert deleted rows = ", v_rows; end if;  
   
   
   
   
   delete l
   from   survey_used s,
          links  l
   where  s.qnid = p_qnid
   and    s.suid = l.suid;
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "links deleted rows = ", v_rows; end if;
   delete r
   from   survey_used s,
          ab_emails   m,
          ab_email_recipients  r
   where  s.qnid    = p_qnid
   and    s.suid    = m.suid
   and    m.ab_emid = r.ab_emid;
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "ab_email_recipients deleted rows = ", v_rows; end if;
   delete r
   from   survey_used s,
          ab_emails   m,
          ImportDB.key_migrate r
   where  s.qnid    = p_qnid
   and    s.suid    = m.suid
   and    r.mysql_tab = "ab_emails"
   and    m.ab_emid   = r.mysql_id;
   
   set v_rows = ROW_COUNT(); 
   
   if @sp_debug = 1 then select "ab_emails - ImportDB.key_migrate deleted rows = ", v_rows; end if;
   delete m
   from   survey_used s,
          ab_emails   m
   where  s.qnid    = p_qnid
   and    s.suid    = m.suid;
   set v_rows = ROW_COUNT();
   
   if @sp_debug = 1 then select "ab_emails deleted rows = ", v_rows; end if;
   
 
   
   delete from survey_used
   where  qnid = p_qnid;
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "survey_used deleted rows = ", v_rows; end if;
   
   delete from qn_languages
   where  qnid = p_qnid;
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "qn_languages deleted rows = ", v_rows; end if;
   
   delete a
   from   result_variable_ans a,
          rids  r
   where  r.qnid = p_qnid
   and    r.rid  = a.rid;
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "result_variable_ans deleted rows = ", v_rows; end if;
   
   delete a
   from   result_element_header a,
          rids  r
   where  r.qnid = p_qnid
   and    r.rid  = a.rid;
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "result_element_header deleted rows = ", v_rows; end if;
   
   delete a
   from   result_detail a,
          rids  r
   where  r.qnid = p_qnid
   and    r.rid  = a.rid;  
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "result_detail deleted rows = ", v_rows; end if;
   
   delete a
   from   result a,
          rids  r
   where  r.qnid = p_qnid
   and    r.rid  = a.rid;  
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "result deleted rows = ", v_rows; end if;
   
   delete from rids
   where  qnid = p_qnid;
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "rids deleted rows = ", v_rows; end if;
   
   delete from ImportDB.import_rpatid_map where qnid = p_qnid;
   
   delete r
   from   page      p,
          question  q,
          respattern r
   where  p.qnid = p_qnid
   and    p.pid  = q.pid
   and    q.qid  = r.qid;
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "respattern deleted rows = ", v_rows; end if;
   delete er
   from   page      p,
          question  q,
          element   e,
          element_rtype er
   where  p.qnid = p_qnid
   and    p.pid  = q.pid
   and    q.qid  = e.qid
   and    e.eid  = er.eid;
   
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "element_rtype deleted rows = ", v_rows; end if;
   
   
   delete e
   from   page      p,
          question  q,
          element   e
   where  p.qnid = p_qnid
   and    p.pid  = q.pid
   and    q.qid  = e.qid;
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "element deleted rows = ", v_rows; end if;
   delete qr
   from   page      p,
          question  q,
          question_rtype qr
   where  p.qnid = p_qnid
   and    p.pid  = q.pid
   and    q.qid  = qr.qid;
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "question_rtype deleted rows = ", v_rows; end if;
   
   delete q
   from   page      p,
          question  q
   where  p.qnid = p_qnid
   and    p.pid  = q.pid;
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "question deleted rows = ", v_rows; end if;
   
   delete from page
   where  qnid = p_qnid;
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "page deleted rows = ", v_rows; end if;
   
   delete from questionnaire
   where  qnid = p_qnid;
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "questionnaire deleted rows = ", v_rows; end if;
 
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `qn_question_build`( INOUT p_qid          integer unsigned,
          IN  p_action         char(1), 
          IN  p_pid            integer unsigned,
          IN  p_qtype          varchar(500),
          IN  p_txt_validation char(1),  
          IN  p_orig_qid       integer unsigned,
          
          IN  p_active         tinyint unsigned,
          IN  p_order_seq      smallint unsigned,
          IN  p_title          varchar(500),
          IN  p_short_name     varchar(255),
          IN  p_param_name     varchar(255)
         )
stored_procedure:
begin
   declare v_qtypeid integer unsigned;
   declare v_rows, v_err  int default 0;
   
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   
   select qtypeid  into v_qtypeid
   from   qtype
   where  title = p_qtype;
   
   SET v_rows = ROW_COUNT();
   if v_rows != 1 then
      set @sp_return_stat = 1;
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = 'qn_question_build: unknown question type', MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;
   
   
   
   case p_action 
   when "U" then
   
      update question
      set   pid        = p_pid,
            qtypeid    = v_qtypeid,
            txt_validation = p_txt_validation,
            orig_qid   = p_orig_qid,
            active     = p_active,
            order_seq  = p_order_seq,
            title      = p_title,
            short_name = p_short_name,
            param_name = p_param_name
      where qid = p_qid;
      set v_rows = ROW_COUNT();
      
      if v_rows != 1 then
         set @sp_return_stat = 1;
         SIGNAL SQLSTATE '01000'
         SET MESSAGE_TEXT = 'qn_question_build: update failed', MYSQL_ERRNO = 1000;
         leave stored_procedure; 
      end if;
   
   when "I" then
      insert question ( pid,   qtypeid,  txt_validation,   orig_qid,   active,   order_seq,   title,   short_name,   param_name) 
               values ( p_pid, v_qtypeid,p_txt_validation, p_orig_qid, p_active, p_order_seq, p_title, p_short_name, p_param_name);
      SET p_qid = LAST_INSERT_ID();
      
      if @sp_debug = 1 then
         select p_qid as p_qid;
      end if;
      
      if ( p_qtype = "text" or p_qtype = "parameter" or p_qtype = "essay" ) then
         
        
         insert element( qid,   orig_eid, name,    dimension, order_seq, type, active, score )
                values ( p_qid, 0,        p_qtype, 1,          1,        "N",  1,      null  );
      end if;
   else
      begin end; 
   end case;
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `qn_rtype_auto_configure`( IN p_qnid          integer unsigned
         )
stored_procedure:
begin
   declare v_qtypeid integer unsigned;
      declare v_msg                    varchar(255);
   declare v_rows, v_err  int default 0;
   
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   if not exists( select qnid from questionnaire where qnid = p_qnid ) then
      set @sp_return_stat = 1, v_msg = concat( 'qn_rtype_auto_configure: unknown qnid ', p_qnid);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;  
   
   
   CREATE TEMPORARY TABLE t_q_rtype_map ENGINE=MEMORY
   select R.rtypeid as q_rtypeid, Q.param_name, 0 as q_mapped, Q.qid, QT.title as q_type, QT.dimension,
          Q.title
   from   page P
   inner join question Q
      on   P.qnid  = p_qnid 
      and  P.pid   = Q.pid
   inner join qtype QT
      on   Q.qtypeid = QT.qtypeid
      and  QT.title not in ( "pres_text", "parameter" )
    left outer join rtype R
       on  R.class = "G"
       and Q.param_name = R.rtype_name;
       
   
   
   update t_q_rtype_map m,
          question_rtype qrt
   set    q_mapped = 1  
   where  m.qid = qrt.qid
   and    m.q_rtypeid is not null; 
   
   if @sp_debug = 1 then  select * from t_q_rtype_map order by qid; end if;
   
   CREATE TEMPORARY TABLE t_e1_rtype_map ENGINE=MEMORY
   select  M.q_rtypeid, M.param_name as q_rtype_name, 
           RTH.rtype_name as E1_rtype_name, E1.qid, E1.eid, RTH.rtypeid as E1_rtypeid, 
           E1.name as E1_name, RTH.search_term as E1_search_term, M.dimension as max_dimension,
           0 as e1_mapped
   from    t_q_rtype_map M
   inner join element    E1
      on  M.qid        = E1.qid
      and E1.dimension = 1
      and q_rtypeid is not null
   left outer join rslt_rtype_hierarchy RTH
      on  M.q_rtypeid  =  RTH.p_rtypeid
      and (    E1.name    like  concat( "%",RTH.search_term, "%" ) 
            or E1.name in ("text", "essay") and RTH.search_term = "comment" )
   order by M.qid, E1.order_seq;
   update t_e1_rtype_map m,
          element_rtype ert
   set    e1_mapped = 1  
   where  m.eid = ert.eid
   and    m.E1_rtypeid is not null; 
   if @sp_debug = 1 then  select * from t_e1_rtype_map; end if;
   
   
   
   CREATE TEMPORARY TABLE t_e2_rtype_map ENGINE=MEMORY
   select  distinct 
           RTH.rtype_name as E1_rtype_name, E2.qid, E2.eid, RTH.rtypeid as E2_rtypeid, 
           E2.name as E2_name, RTH.search_term as E2_search_term, M.max_dimension,
           0 as e2_mapped
   from    t_e1_rtype_map M
   inner join element     E2
      on  M.qid        = E2.qid
      and M.max_dimension > 1
      and E2.dimension    = 2
      and E1_rtypeid is not null
   left outer join rslt_rtype_hierarchy RTH
      on  M.E1_rtypeid  =  RTH.p_rtypeid
      and (    E2.name    like  concat( "%",RTH.search_term, "%" ) )
   order by M.qid, E2.order_seq;
   update t_e2_rtype_map m,
          element_rtype ert
   set    e2_mapped = 1  
   where  m.eid = ert.eid
   and    m.E2_rtypeid is not null; 
   if @sp_debug = 1 then   select * from t_e2_rtype_map; end if;
   
   insert question_rtype( qid, rtypeid )
      select qid, max( q_rtypeid )
      from   t_q_rtype_map
      where  q_mapped = 0
      and    q_rtypeid is not null
      group by qid;
   insert element_rtype( eid, rtypeid )
      select eid, max(E1_rtypeid)
      from   t_e1_rtype_map
      where  e1_mapped = 0
      and    E1_rtypeid is not null
      group by eid;
   insert element_rtype( eid, rtypeid )
      select eid, max(E2_rtypeid)
      from   t_e2_rtype_map
      where  e2_mapped = 0
      and    E2_rtypeid is not null
      group by eid;
   call rslt_set_rtypes_on_rpats ( p_qnid ); 
   
   DROP TEMPORARY TABLE t_e2_rtype_map;
   DROP TEMPORARY TABLE t_e1_rtype_map;
   DROP TEMPORARY TABLE t_q_rtype_map;
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_ANALYSED`( IN p_rpid      integer unsigned,
          IN p_uid       integer unsigned
         )
stored_procedure:
begin
   declare v_rpt_type               varchar(3);
   declare v_top_org_type           char(1);
   declare v_rpt_top_orgid          integer unsigned; 
   declare v_rpt_top_qnid           integer unsigned;
   
   declare v_survey_count           integer;
   declare v_RPT_SETUP_rfs_id       integer unsigned;
   declare v_RPT_ORG_RESULTS_rfs_id integer unsigned;
          
   declare v_msg                    varchar(255);
   declare v_rows, v_err            int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   call rpt_smry_prepare_env 
        ( p_rpid, p_uid,
          
          v_rpt_type, v_top_org_type, v_rpt_top_orgid, v_rpt_top_qnid, v_survey_count, 
          v_RPT_SETUP_rfs_id, v_RPT_ORG_RESULTS_rfs_id 
        );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   
   insert t_rpat_spec( rfs_id, collect_counts,
                       qnid, resgroup, rpatid, txt_validation, qid, eid1, eid2, eid3, score, rt_patid)         
      select v_RPT_ORG_RESULTS_rfs_id as rfs_id, 
             1 as collect_all_ans,
             r.qnid, r.resgroup, r.rpatid, r.txt_validation, r.qid, r.eid1, r.eid2, r.eid3, r.score, r.rt_patid 
      from   rslt_rpat_spec_setup r  
      where  r.qid in
       ( select distinct q.qid 
         from   t_rpt_survey   s,
                page           p,
                question       q,
                question_rtype qr,
                rtype q_rt
         where org_type   = "S"
         and   s.qnid     = p.qnid
         and   p.pid      = q.pid
         and   q.qid      = qr.qid
         and   qr.rtypeid = q_rt.rtypeid
         and   r.type = "NN"
         and   q_rt.rtype_name in ("Q_KPI_MAIN",  "Q_KPI_RECEPTION_AND_PROPERTY", "Q_KPI_ROOM" )  );
   
   call rpt_smry_collect_counts
        ( v_top_org_type, v_rpt_top_qnid, v_RPT_SETUP_rfs_id, v_RPT_ORG_RESULTS_rfs_id 
        );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   
   
   call rpt_smry_standard_output
        ( v_RPT_ORG_RESULTS_rfs_id,
          v_top_org_type,
          v_survey_count,
          v_rpt_top_qnid,
          1 
         );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_ASSOC_DATA_EXTRACT`( IN p_rpid      integer unsigned,
          IN p_uid       integer unsigned
         )
stored_procedure:
begin
   declare v_rpt_type               varchar(3);
   declare v_top_org_type           char(1);
   declare v_rpt_top_orgid          integer unsigned; 
   declare v_rpt_top_qnid           integer unsigned;
   
   declare v_survey_count           integer;
   declare v_RPT_SETUP_rfs_id       integer unsigned;
   declare v_RPT_ORG_RESULTS_rfs_id integer unsigned;
          
   declare v_msg                    varchar(255);
   declare v_rows, v_err            int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   call rpt_smry_prepare_env 
        ( p_rpid, p_uid,
          
          v_rpt_type, v_top_org_type, v_rpt_top_orgid, v_rpt_top_qnid, v_survey_count, 
          v_RPT_SETUP_rfs_id, v_RPT_ORG_RESULTS_rfs_id 
        );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
      insert t_rpat_spec( rfs_id, collect_counts,
                       qnid, resgroup, rpatid, txt_validation, qid, eid1, eid2, eid3, score, rt_patid)         
      select v_RPT_ORG_RESULTS_rfs_id as rfs_id, 
             1 as collect_all_ans,
             r.qnid, r.resgroup, r.rpatid, r.txt_validation, r.qid, r.eid1, r.eid2, r.eid3, r.score, r.rt_patid 
      from   rslt_rpat_spec_setup r  
      where  r.qid in
       ( select distinct q.qid 
         from   t_rpt_survey   s,
                page           p,
                question       q,
                question_rtype qr,
                rtype q_rt
         where org_type   = "S"
         and   s.qnid     = p.qnid
         and   p.pid      = q.pid
         and   q.qid      = qr.qid
         and   qr.rtypeid = q_rt.rtypeid
         
         and   q_rt.rtype_name in ( "Q_PROMOTIONAL_MATERIAL_EMAIL", "Q_HOBBY_INTREST" ) );
         
   call rpt_smry_collect_counts
        ( v_top_org_type, v_rpt_top_qnid, v_RPT_SETUP_rfs_id, v_RPT_ORG_RESULTS_rfs_id 
        );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   
   call rpt_smry_standard_output
        ( v_RPT_ORG_RESULTS_rfs_id,
          v_top_org_type,
          v_survey_count,
          v_rpt_top_qnid,
          1 
         );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_bld_report_structure`( IN p_rpid      integer unsigned,
          IN p_mode      varchar(3), 
          IN p_qnid      integer unsigned   
         )
stored_procedure:
begin
   declare v_org_type            char(1);
   declare v_rpt_type            char(3);
   
   declare v_retid                int unsigned;
   declare v_rpt_tmplt_id         int unsigned;
   declare v_renderid             int unsigned;
   declare v_name                 varchar(255);
   declare v_position_type        char(1);
   declare v_order_seq            smallint;
   declare v_source_object        char(1);
   declare v_qtypeid              int unsigned;
   declare v_rtypeid              int unsigned ;
   declare v_entry_type           varchar(4);
   declare v_format               varchar(255);
   declare v_counters             char(4);
   declare v_instruction          varchar(255);
   declare v_rtype_name           varchar(255);
   
   declare v_no_data              int;
   declare v_msg                   varchar(255);
   declare v_rows, v_err          int default 0;  
   
   declare curse1 cursor for
      select retid, E.rpt_tmplt_id, E.renderid, E.name, position_type, E.order_seq, source_object, 
             qtypeid, E.rtypeid, entry_type, format, counters, instruction, T.rtype_name
      from  report_template R,
            report_entry_template E,
            rtype T
      where R.rpt_tmplt_id = E.rpt_tmplt_id
      and   E.rtypeid      = T.rtypeid
      and   position_type  = "A"
      and   R.org_type     = v_org_type
      and   R.rpt_type     = v_rpt_type
      order by E.order_seq;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   
   declare CONTINUE handler for NOT FOUND
   begin
      set v_no_data = TRUE;
   end;
   set @sp_return_stat = 0;
   
   if p_mode != "NEW" then
      set @sp_return_stat = 1, v_msg = concat( 'rpt_bld_report_structure surveys: unknown mode = ', p_mode);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure;
   end if;
   
   select O.type, R.rpt_type into v_org_type, v_rpt_type
   from   report R,
          organisation O
   where  R.rpid  = p_rpid
   and    R.orgid = O.orgid;
   set v_rows = ROW_COUNT();   
   if v_rows != 1 then
      set @sp_return_stat = 1, v_msg = concat( 'rpt_bld_report_structure surveys: no data for repid ', p_rpid);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if; 
 
   if p_qnid is null then
      select U.qnid into p_qnid 
      from   report R,
             survey_used U
      where  R.rpid    = p_rpid
      and    R.orgid   = U.orgid
      and    U.active  = 1
      and    U.date_end is null; 
      set v_rows = ROW_COUNT(); 
 
      if v_rows != 1 then
         set @sp_return_stat = 1, v_msg = concat( 'rpt_bld_report_structure surveys: survey unclear for rpid ', p_rpid);
         SIGNAL SQLSTATE '01000'
         SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
         leave stored_procedure; 
      end if; 
   end if;
   
   if @sp_debug = 1 then select v_org_type, v_rpt_type; end if;
   delete from report_entry where rpid = p_rpid; 
   set v_no_data = 0, v_order_seq = 0; 
   open curse1;
   curse1_loop: 
   loop 
      fetch curse1 into v_retid, v_rpt_tmplt_id, v_renderid, v_name, v_position_type, v_order_seq, v_source_object, 
             v_qtypeid, v_rtypeid, v_entry_type, v_format, v_counters, v_instruction, v_rtype_name;
      if v_no_data then leave curse1_loop; end if;
      
      
      set v_order_seq = v_order_seq + 1;
      if @sp_debug = 1 then select v_order_seq, v_name, v_rtype_name; end if;
  
      case ifnull( v_instruction, "NONE" )
      when "NONE"  then
         insert report_entry
           (rpid, renderid, order_seq, active, entry_type, display, format, counters, source_object, rtypeid) values
           (p_rpid, v_renderid, v_order_seq, 1, v_entry_type, 1,v_format, v_counters, v_source_object, v_rtypeid);
      when "Q_RTYPE_EXISTS" then 
         if exists (
              select p.qnid  
              from   page           p,
                     question       q,
                     question_rtype qr
              where  p.qnid     = p_qnid
              and    p.pid      = q.pid
              and    q.qid      = qr.qid
              and    qr.rtypeid = v_rtypeid ) then
            insert report_entry
              (rpid, renderid, order_seq, active, entry_type, display, format, counters, source_object, rtypeid) values
              (p_rpid, v_renderid, v_order_seq, 1, v_entry_type, 1,v_format, v_counters, v_source_object, v_rtypeid);
           else
              set v_order_seq = v_order_seq - 1; 
           end if;
      when "ELE_RTYPE_EXISTS" then 
         if exists (
              select p.qnid  
              from   page           p,
                     question       q,
                     element        e,
                     element_rtype  er
              where  p.qnid     = p_qnid
              and    p.pid      = q.pid
              and    q.qid      = e.qid
              and    e.eid      = er.eid
              and    er.rtypeid = v_rtypeid ) then
            insert report_entry
              (rpid, renderid, order_seq, active, entry_type, display, format, counters, source_object, rtypeid) values
              (p_rpid, v_renderid, v_order_seq, 1, v_entry_type, 1,v_format, v_counters, v_source_object, v_rtypeid);
           else
              set v_order_seq = v_order_seq - 1; 
           end if;
 
      when  "COPY_REST_OF_SURVEY_Q" then
         call rpt_bld_rest_of_srvy_ent_pnts ( p_rpid,  p_mode, p_qnid );
         if @sp_return_stat = 1 then leave stored_procedure; end if;
      
      else begin end;
      end case;
      
   end loop;
  close curse1;
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_bld_rest_of_srvy_ent_pnts`( IN p_rpid         integer unsigned,
          IN p_mode         varchar(3), 
          IN p_qnid         integer unsigned   
         )
stored_procedure:
begin
   declare v_qnid, v_qid       integer unsigned;
   declare v_q_dimension       tinyint;       
   declare v_org_type          varchar(1);
   declare v_rpt_type          varchar(3);
   
   declare v_retid             int unsigned;
   declare v_rpt_tmplt_id      int unsigned;
   declare v_renderid          int unsigned;
   declare v_name              varchar(255);
   declare v_position_type     char(1);
   declare v_order_seq         smallint;
   declare v_source_object     char(1);
   declare v_qtypeid           int unsigned;
   declare v_rtypeid           int unsigned ;
   declare v_entry_type        varchar(4);
   declare v_format            varchar(255);
   declare v_counters          char(4);
   declare v_instruction       varchar(255);
   declare v_rtype_name        varchar(255);
   
   declare v_no_data           tinyint;
   declare v_msg, v_qtype      varchar(255);
   declare v_rows, v_err       int default 0;  
   
   declare curse1 cursor for
      select q.qid, qt.title as qtype, qt.dimension,
             T.retid, T.rpt_tmplt_id, T.renderid, T.name, T.position_type, T.source_object, 
             T.qtypeid, qr.rtypeid, T.entry_type, T.format, T.counters, T.instruction, R.rtype_name 
       from  page           p,
             question       q,
             qtype          qt,
             question_rtype qr,
             report_entry_template T,
             rtype          R
      where  p.qnid    = v_qnid
      and    p.pid     = q.pid
      and    q.qtypeid = qt.qtypeid
      and    q.qid     = qr.qid
      and    qt.title not in ( 'pres_image', 'pres_text' )
      and    T.rpt_tmplt_id  = v_rpt_tmplt_id
      and    T.source_object = "Q" 
      and    T.position_type = "R" 
      and    q.qtypeid       = T.qtypeid 
      and    qr.rtypeid      = R.rtypeid 
      and    R.class        != "C" 
      and    R.rtypeid not in ( select rtypeid from report_entry where rpid = p_rpid )
      order by p.order_seq, q.order_seq;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   
   declare CONTINUE handler for NOT FOUND
   begin
      set v_no_data = TRUE;
   end;
   if p_mode != "NEW" then
      set @sp_return_stat = 1, v_msg = concat( 'rpt_bld_report_structure surveys: unknown mode = ', p_mode);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure;
   end if;
   set @sp_return_stat = 0,
       v_order_seq = 0;    
 
   select U.qnid, type, rpt_type into v_qnid, v_org_type, v_rpt_type
   from   report R,
          organisation O,
          survey_used U
   where  R.rpid    = p_rpid
   and    R.orgid   = O.orgid
   and    R.orgid   = U.orgid
   and    U.active  = 1
   and    U.date_end is null; 
   set v_rows = ROW_COUNT(); 
 
   if v_rows != 1 then
      set @sp_return_stat = 1, v_msg = concat( 'rpt_bld_rest_of_srvy_ent_pnts surveys: survey unclear for repid ', p_rpid);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if; 
   
   if p_qnid > 0 then set v_qnid = p_qnid; end if;
   
   if @sp_debug = 1 then select "dbg", v_qnid, v_org_type, v_rpt_type; end if;
   select rpt_tmplt_id into v_rpt_tmplt_id  
   from   report_template
   where  org_type = v_org_type
   and    rpt_type = v_rpt_type;
   set v_rows = ROW_COUNT(); 
   if v_rows != 1 then
      set @sp_return_stat = 1, v_msg = concat( 'rpt_bld_rest_of_srvy_ent_pnts surveys: report_template unknown for repid ', p_rpid);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;
   select max( order_seq ) into v_order_seq
   from   report_entry
   where  rpid = p_rpid;
   set   v_order_seq = ifnull(v_order_seq, 0);
   
   open curse1;
   
   set v_no_data = 0;
   curse1_loop: 
   loop 
      fetch curse1 into 
             v_qid, v_qtype, v_q_dimension,
             v_retid, v_rpt_tmplt_id, v_renderid, v_name, v_position_type, v_source_object, 
             v_qtypeid, v_rtypeid, v_entry_type, v_format, v_counters, v_instruction, v_rtype_name;
      if v_no_data then leave curse1_loop; end if;
      set v_order_seq = v_order_seq + 1;
      if @sp_debug = 1 then select "dbg loop", v_order_seq, v_qid, v_qtype, v_q_dimension, v_name; end if;
      insert report_entry
        (rpid, renderid, order_seq, active, entry_type, display, format, counters, source_object, rtypeid, qid, pre_page_break_on ) 
         select p_rpid, v_renderid, v_order_seq, 1, v_entry_type, 1,v_format, v_counters, v_source_object, v_rtypeid,
                case v_org_type when "S" then v_qid else null end, 0 ; 
                
        
   end loop;
  close curse1;
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_clone_for_save_as`( IN  p_old_rpid       integer unsigned,
          IN  p_new_owner_uid  integer unsigned,
          IN  p_new_rpt_name   varchar(255),
          OUT p_new_rpt_id     integer unsigned
         )
stored_procedure:
begin
   declare v_old_owner_uid          integer unsigned;
   declare v_old_rfs_id             integer unsigned;
   declare v_new_rfs_id             integer unsigned;
   declare v_msg                    varchar(255);
   declare v_rows, v_err            int default 0;
   
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   select owner_uid into v_old_owner_uid
   from report where rpid = p_old_rpid;
   set v_rows = ROW_COUNT();
   
   if v_rows != 1 then
      set @sp_return_stat = 1, v_msg = concat( 'rpt_clone_for_save_as: not found rpid ', p_old_rpid);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;
   
   insert report( owner_uid,  orgid, renderid, is_user, rpt_type, name, shared )
      select p_new_owner_uid, orgid, renderid, 1,      rpt_type, p_new_rpt_name, 0
      from report
      where rpid = p_old_rpid;
   set v_rows = ROW_COUNT(), p_new_rpt_id = LAST_INSERT_ID();
   insert report_entry( rpid, renderid, order_seq, active, entry_type, display, 
                        format, counters, source_object, rtypeid, qid, pre_page_break_on )
      select p_new_rpt_id, renderid, order_seq, active, entry_type, display, 
                        format, counters, source_object, rtypeid, qid, pre_page_break_on
      from   report_entry
      where  rpid   = p_old_rpid;
 
   select rfs_id into  v_old_rfs_id
   from  rslt_filter_set 
   where rpid = p_old_rpid 
   and   uid  = v_old_owner_uid 
   and   name = "RPT_SETUP";
 
   insert rslt_filter_set (rpid,   uid,   is_user, name) 
                      values (p_new_rpt_id, p_new_owner_uid, 1, "RPT_SETUP" );
   set v_new_rfs_id = LAST_INSERT_ID();
   insert rslt_filter_item( rfs_id, active, item_type, qnid, rpatid, 
             val_name, val_type, val_I, val_T, val_S )
         select v_new_rfs_id, active, item_type, qnid, rpatid, 
                val_name, val_type, val_I, val_T, val_S 
         from   rslt_filter_item
         where  rfs_id = v_old_rfs_id
         and    active = 1;
         
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_COMPARISOM`( IN p_rpid      integer unsigned,
          IN p_uid       integer unsigned
         )
stored_procedure:
begin
   declare v_rpt_type               varchar(3);
   declare v_top_org_type           char(1);
   declare v_rpt_top_orgid          integer unsigned; 
   declare v_rpt_top_qnid           integer unsigned;
   
   declare v_survey_count           integer;
   declare v_RPT_SETUP_rfs_id       integer unsigned;
   declare v_RPT_ORG_RESULTS_rfs_id integer unsigned;
   
   declare v_pos_neg_clicks         integer unsigned;
   declare v_total_clicks           integer unsigned;
   declare v_msg                    varchar(255);
   declare v_rows, v_err            int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   call rpt_smry_prepare_env 
        ( p_rpid, p_uid,
          
          v_rpt_type, v_top_org_type, v_rpt_top_orgid, v_rpt_top_qnid, v_survey_count, 
          v_RPT_SETUP_rfs_id, v_RPT_ORG_RESULTS_rfs_id 
        );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   
   
   insert t_rpat_spec( rfs_id, collect_counts,
                       qnid, resgroup, rpatid, txt_validation, qid, eid1, eid2, eid3, score, rt_patid)         
      select v_RPT_ORG_RESULTS_rfs_id as rfs_id, 
             1 as collect_all_ans,
             r.qnid, r.resgroup, r.rpatid, r.txt_validation, r.qid, r.eid1, r.eid2, r.eid3, r.score, r.rt_patid 
      from   rslt_rpat_spec_setup r  
      where  r.qid in
       ( select distinct q.qid 
         from   t_rpt_survey   s,
                page           p,
                question       q,
                question_rtype qr,
                rtype q_rt
         where org_type   = "S"
         and   s.qnid     = p.qnid
         and   p.pid      = q.pid
         and   q.qid      = qr.qid
         and   qr.rtypeid = q_rt.rtypeid
         and   r.type = "NN"
         and   q_rt.rtype_name = "Q_KPI_MAIN" );
   call rpt_smry_collect_counts
        ( v_top_org_type, v_rpt_top_qnid, v_RPT_SETUP_rfs_id, v_RPT_ORG_RESULTS_rfs_id 
        );         
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   
   
   
   
   select "kpi_scores" as data_set,
          org.name,   
          rt.rtype_name,
          sign(rp.score - 3) as grp,
          sum(rc.clicks) as clicks
   from   organisation  org,
          t_rpt_survey  sy,
          t_rslt_count  rc,
          respattern    rp,
          rtype_pattern tp,
          rtype         rt
   where  org.orgid     = sy.orgid
   and    org.type      = "S"
   and    sy.qnid       = rc.qnid
   and    rc.rfs_id     = v_RPT_ORG_RESULTS_rfs_id
   and    rc.typ        = "CNT"
   and    rc.rpatid     = rp.rpatid
   and    rp.rt_patid   = tp.rt_patid
   and    tp.e1_rtypeid = rt.rtypeid
   and    rp.score >= 1 and rp.score <= 5
   group by org.name, rt.rtype_name, sign(rp.score - 3);
   
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_DASHBOARD_KPI`( 
          IN  p_rpid    integer unsigned,
          IN  p_uid     integer unsigned
        )
stored_procedure:
begin
   declare v_rfs_id                integer unsigned;
   declare v_mf_filter_before_date,
           v_mf_filter_after_date,
           v_trend_start_date,
           v_trend_end_date         datetime;
   declare v_date_grouping          char(3);
   declare v_msg                    varchar(255);
   declare v_rows, v_err            int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   -- Could check that rpid is an overview ?
   
   -- App ensures this exists so just picking up rfs_id
   call rpt_establish_filter_set (
            p_rpid,        -- IN p_rpid 
            p_uid,         -- IN p_uid
            "RPT_SETUP",   -- IN p_filter_name 
            0,             -- IN p_copy_rpt_owner,
            v_rfs_id       -- OUT p_user_rfs_id
         );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   -- saves dates as will need to run report with 3 month trend
   set v_mf_filter_before_date = fltr_meta_item_get_T( v_rfs_id, "filter_before_date"),
       v_mf_filter_after_date  = fltr_meta_item_get_T( v_rfs_id, "filter_after_date" ),
       v_trend_start_date      = DATE_SUB( DATE_FORMAT(now(), '%Y-%m-01 00:00:00.000000'), INTERVAL 3 MONTH),
       v_trend_end_date        = DATE_FORMAT( LAST_DAY( DATE_SUB( now(), INTERVAL 1 MONTH )),'%Y-%m-%d 23:59:59.999999'),
       v_date_grouping         = fltr_meta_item_get_S( v_rfs_id, "date_group" );
   if @sp_debug > 0 then
      select "Debug>", v_mf_filter_before_date, v_mf_filter_after_date, v_date_grouping, v_trend_start_date, v_trend_end_date;
   end if;
   
   if v_date_grouping is not null then
      update rslt_filter_item 
      set    active = 0 
      where  rfs_id   = v_rfs_id
      and    val_name = "date_group";
   end if;
   
   call rpt_OVERVIEW ( p_rpid, p_uid );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   -- TREND: change dates to 3 month range & monthly data grouping
   update rslt_filter_item 
   set    active   = 1, val_S = "M"
   where  rfs_id   = v_rfs_id
   and    val_name = "date_group";
   SET v_rows = ROW_COUNT();
   if v_rows = 0 then
         insert into rslt_filter_item (rfs_id, active, item_type,     val_name, val_type, val_S) 
            values( v_rfs_id, 1, "meta_filter", "date_group", "S", "M" );
   end if;
   update rslt_filter_item 
   set    val_T =  v_trend_end_date
   where rfs_id   = v_rfs_id
   and   val_name = "filter_before_date";
   update rslt_filter_item 
   set    val_T = v_trend_start_date
   where rfs_id   = v_rfs_id
   and   val_name = "filter_after_date";
   call rpt_OVERVIEW ( p_rpid, p_uid );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   
   -- restore user dates
   update rslt_filter_item 
   set    active = 0 
   where  rfs_id   = v_rfs_id
   and    val_name = "date_group";
   update rslt_filter_item 
   set    val_T =  v_mf_filter_before_date
   where rfs_id   = v_rfs_id
   and   val_name = "filter_before_date";
   update rslt_filter_item 
   set    val_T = v_mf_filter_after_date
   where rfs_id   = v_rfs_id
   and   val_name = "filter_after_date";
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_driver`( IN p_rpid      integer unsigned,
          IN p_uid       integer unsigned
         )
stored_procedure:
begin
   declare v_rpt_type               varchar(3);
   declare v_top_org_type           char(1);
   declare v_survey_count           integer;
   declare v_rpt_top_orgid,
           v_rpt_top_qnid,
           v_RPT_SETUP_rfs_id,
           v_RPT_ORG_RESULTS_rfs_id integer unsigned;
           
   declare v_filter_before_date,
           v_filter_after_date      datetime;
   declare v_msg                    varchar(255);
   declare v_rows, v_err            int default 0;
   
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   
   select R.rpt_type, R.orgid into v_rpt_type, v_rpt_top_orgid
   from   report       R
   where  R.rpid  = p_rpid;
   
   set v_rows = ROW_COUNT();
   if v_rows != 1 then
      set @sp_return_stat = 1, v_msg = concat( 'rpt_driver: unknown rpid ', p_rpid);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if; 
   call rpt_tables_setup ( "CREATE" );
   
   
   call rpt_establish_filter_set (
          p_rpid,                  
          p_uid,                   
          "RPT_SETUP",             
          1,                       
          v_RPT_SETUP_rfs_id       
          );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
      
   
   call rpt_establish_filter_set (
          p_rpid,                  
          p_uid,                   
          "RPT_ORG_RESULTS",       
          0,                       
          v_RPT_ORG_RESULTS_rfs_id 
          );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   call rpt_identify_orgs_and_surveys (
     p_rpid,                   
     p_uid,                    
     v_RPT_SETUP_rfs_id,       
     v_RPT_ORG_RESULTS_rfs_id, 
     v_survey_count,           
     v_rpt_top_qnid,           
     v_top_org_type            
     );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   
   
   
   insert t_rpat_spec( rfs_id, qnid, resgroup, collect_counts, 
                      rpatid, txt_validation, qid, eid1, eid2, eid3, score, rt_patid)
      select v_RPT_ORG_RESULTS_rfs_id as rfs_id, 
             p.qnid,
             qt.resgroup,
             1 as collect_counts,  
             rp.rpatid,
             q.txt_validation,
             q.qid, rp.eid1, rp.eid2, rp.eid3, rp.score,
             rp.rt_patid                                 
      from   t_rpt_survey  s,
             page          p,
             question      q,
             qtype         qt,
             respattern    rp
      where  s.qnid    = p.qnid
      and    p.pid     = q.pid
      and    q.qtypeid = qt.qtypeid
      and    q.qid     = rp.qid;
      
      
   call rpt_setup_survey_filters ( v_top_org_type, v_RPT_SETUP_rfs_id, v_RPT_ORG_RESULTS_rfs_id );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   
   call rslt_build_filtered_rid_list( v_rpt_top_qnid, v_RPT_ORG_RESULTS_rfs_id );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   
   call rslt_build_clicks( v_RPT_ORG_RESULTS_rfs_id, 0 );
   call rslt_build_mode_median_mean (
        v_RPT_ORG_RESULTS_rfs_id, 
        1, 
        0, 
        0  
      );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   
   insert t_rid_grp_counts( rfs_id, qnid, grouping, is_2dm, grp_key, rids )
      select v_RPT_ORG_RESULTS_rfs_id,
             rd.qnid,
             rd.grouping,
             0 as is_2dm, 
             rp.qid as grp_key,  
             count( distinct rt.rid ) as rids
      from
              t_rids      rd,
              result      rt,
              t_rpat_spec rp
      where   1 
      and     rd.rfs_id = v_RPT_ORG_RESULTS_rfs_id
      and     rp.rfs_id = v_RPT_ORG_RESULTS_rfs_id
      and     rd.rid    = rt.rid
      and     rt.rpatid = rp.rpatid
      and     rp.resgroup like "1DM%" 
      and     rp.collect_counts = 1
      group by rd.qnid, rd.grouping, rp.qid;
      
   
   insert t_rid_grp_counts( rfs_id, qnid, grouping, is_2dm, grp_key, rids )
      select v_RPT_ORG_RESULTS_rfs_id,
             rd.qnid,
             rd.grouping,
             1 as is_2dm, 
             rp.eid1 as grp_key,  
             count( distinct rt.rid ) as rids
      from
              t_rids      rd,
              result      rt,
              t_rpat_spec rp
      where   1 
      and     rd.rfs_id = v_RPT_ORG_RESULTS_rfs_id
      and     rp.rfs_id = v_RPT_ORG_RESULTS_rfs_id
      and     rd.rid    = rt.rid
      and     rt.rpatid = rp.rpatid
      and     rp.resgroup  = "2DM"      
      and     rp.collect_counts = 1
      group by rd.qnid, rd.grouping, rp.eid1;
  
  
  
   if @sp_debug = 1 then
     select "rpt_driver debug data:";
     select * from t_rpt_org;
     select * from t_rpt_survey;
     select * from rslt_filter_item where rfs_id = v_RPT_ORG_RESULTS_rfs_id order by qnid;
     select 
             rc.qnid,
             rc.grouping,
             rc.rpatid,
             rp.qid, rp.eid1, rp.eid2, rp.eid3, 
             rp.score,
             rc.typ,
             rc.clicks,
             cb.rids, 
             rc.av,
             q.title, z.title
     from          t_rslt_count rc
        inner join respattern   rp
           on  rc.rpatid  = rp.rpatid
           and rc.rfs_id  = v_RPT_ORG_RESULTS_rfs_id
        inner join questionnaire z
          on rc.qnid = z.qnid
        inner join question q
           on rp.qid = q.qid 
        left outer join t_rid_grp_counts cb
           on  cb.rfs_id   = v_RPT_ORG_RESULTS_rfs_id
           and rc.qnid     = cb.qnid
           and ifnull(rc.grouping,0) = ifnull(cb.grouping, 0)
           and rc.rpatid   = rp.rpatid            
           and   ( ( cb.is_2dm = 0 and rp.qid  = cb.grp_key ) or
                   ( cb.is_2dm = 1 and rp.eid1 = cb.grp_key ) )
     order by rc.qnid;
   end if;
   
   
   
   
   if v_survey_count = 1 then 
         select 
                rc.qnid,
                rc.grouping,
                rc.rpatid,
                
                rp.score,
                rc.typ,
                rc.clicks,
                cb.rids, 
                rc.av
         from          t_rslt_count rc
            inner join respattern   rp
               on  rc.rpatid  = rp.rpatid
               and rc.rfs_id  = v_RPT_ORG_RESULTS_rfs_id
            left outer join t_rid_grp_counts cb
               on  cb.rfs_id   = v_RPT_ORG_RESULTS_rfs_id
               and rc.qnid     = cb.qnid
               and ifnull(rc.grouping,0) = ifnull(cb.grouping, 0)
               and rc.rpatid   = rp.rpatid            
               and   ( ( cb.is_2dm = 0 and rp.qid  = cb.grp_key ) or
                       ( cb.is_2dm = 1 and rp.eid1 = cb.grp_key ) ); 
   
         select 
                qnid,
                grouping,
                0 as rpatid,
                
                null as score,
                typ, null, rids, null
         from   t_rslt_count 
         where typ not in ("CNT", "AMN")
         and   rfs_id = v_RPT_ORG_RESULTS_rfs_id;
   else   
      
      select 
             v_rpt_top_qnid as qnid,
             rc.grouping,
             tgt_rp.rt_patid,
             
             tgt_rp.score, 
             rc.typ,
             sum(clicks) as clicks,
             sum(cb.rids) as rids,
             sum( rc.av * rc.clicks ) / sum(rc.clicks) as av
      from          t_rslt_count rc
         inner join respattern   src_rp
            on  rc.rfs_id = v_RPT_ORG_RESULTS_rfs_id
            and rc.rpatid = src_rp.rpatid
         inner join t_rpat_spec  tgt_rp
            on  src_rp.rt_patid = tgt_rp.rt_patid
            and tgt_rp.qnid     = v_rpt_top_qnid
            and tgt_rp.rfs_id   = v_RPT_ORG_RESULTS_rfs_id      
         left outer join t_rid_grp_counts cb
            on  cb.rfs_id   = v_RPT_ORG_RESULTS_rfs_id
            and rc.qnid     = cb.qnid
            and ifnull(rc.grouping,0) = ifnull(cb.grouping, 0)
            and rc.rpatid   = src_rp.rpatid            
            and   ( ( cb.is_2dm = 0 and src_rp.qid  = cb.grp_key ) or
                    ( cb.is_2dm = 1 and src_rp.eid1 = cb.grp_key ) )          
       group by grouping, rc.typ, tgt_rp.rpatid;
                
       select 
             v_rpt_top_qnid,
             grouping,
             0 as rpatid,
             
             null as score,
             typ, 
             null as clicks, 
             sum(rids) as rids, 
             null as av
      from   t_rslt_count 
      where typ not in ("CNT", "AMN")
      and   rfs_id = v_RPT_ORG_RESULTS_rfs_id
      group by grouping, typ;
    end if;
   
   
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_ensure_scratchpad_report_setup`( 
          IN  p_uid               integer unsigned,
          IN  p_rpt_type          char(3),
          IN  p_qnid              integer unsigned,  -- set null to use latest, or override to historical when needed
          OUT p_rpid              integer unsigned,
          OUT p_RPT_SETUP_rfs_id  integer unsigned
        )
stored_procedure:
begin
   declare v_orgid             integer unsigned;
   declare v_latest_qnid       integer unsigned;
   declare v_org_type          char(1);
   declare v_rpt_name          varchar(255);
   
   declare v_msg               varchar(255);
   declare v_rows, v_err       int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   -- check users exists
   select O.orgid, O.type, SU.qnid into v_orgid, v_org_type, v_latest_qnid
   from   users U,
          organisation O,
          survey_used  SU
   where  U.uid = p_uid
   and    U.orgid = O.orgid
   and    U.orgid = SU.orgid
   and    SU.active  = 1
   and    SU.date_end is null; -- latest survey 
   set v_rows = ROW_COUNT();
   if v_rows != 1 then
      set @sp_return_stat = 1, v_msg = concat( 'rpt_ensure_scratchpad_report_setup: unable to identify latest qnid & uid via uid=', p_uid);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;
   if p_qnid is null then
      set p_qnid = v_latest_qnid;
   end if;
   -- All scatchpad reports have a standard name format  (view pdf individual Reports needs qnid to descern answers in each survey)
   if p_rpt_type = "R" then
      set v_rpt_name = concat( p_rpt_type, "_", v_orgid, "_", p_uid, "_", p_qnid );
   else
      set v_rpt_name = concat( p_rpt_type, "_", v_orgid, "_", p_uid );
   end if;
   -- select v_orgid, v_org_type, v_rpt_name;
   -- Most of the time a scratchpad report will exist for a user
    select rpid into p_rpid 
    from   report 
    where  orgid     = v_orgid  
    and    owner_uid = p_uid 
    and    rpt_type  = p_rpt_type 
    and    name      = v_rpt_name
    and    is_user   = 0;
    set    v_rows = ROW_COUNT();
   
   if v_rows = 0 then
      insert into report  
               (owner_uid, orgid,   renderid, is_user,   rpt_type, name,       shared) 
         select p_uid,   v_orgid, T.renderid,       0, p_rpt_type, v_rpt_name, 0
         from   report_template T
         where  org_type = v_org_type 
         and    rpt_type = p_rpt_type
         and not exists (select rpid 
                         from   report 
                         where  orgid     = v_orgid  
                         and    owner_uid = p_uid 
                         and    rpt_type  = p_rpt_type 
                         and    name      = v_rpt_name
                         and    is_user   = 0 );
      set p_rpid = LAST_INSERT_ID(), v_rows = ROW_COUNT();
      if v_rows = 1 then
         call rpt_bld_report_structure( p_rpid,   -- IN p_rpid 
                                        "NEW",    -- IN p_mode 
                                        p_qnid ); -- IN p_qnid
         if @sp_return_stat = 1 then leave stored_procedure; end if;
      end if;
   end if;
   
   -- Make sure SETUP filter exists for app.
   call rpt_establish_filter_set (
            p_rpid,                  -- IN p_rpid 
            p_uid,                   -- IN p_uid
            "RPT_SETUP",             -- IN p_filter_name 
            0,                       -- IN p_copy_rpt_owner,
            p_RPT_SETUP_rfs_id       -- OUT p_user_rfs_id
         );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   -- set up last 30 days filter to get the report date range started (only if date filters are missing)
   insert into rslt_filter_item (rfs_id, active, item_type,     val_name, val_type, val_T) 
             select        p_RPT_SETUP_rfs_id, 1,      "meta_filter", "filter_before_date", "T", 
                     DATE_FORMAT(now(), '%Y-%m-%d 23:59:59.999999')
             from    dual
             where   not exists
                (select * from rslt_filter_item where rfs_id = p_RPT_SETUP_rfs_id and item_type = "meta_filter" and val_name = "filter_before_date" );
   insert into rslt_filter_item (rfs_id, active, item_type,     val_name, val_type, val_T) 
             select        p_RPT_SETUP_rfs_id, 1,      "meta_filter", "filter_after_date",  "T",
                     DATE_SUB( DATE_FORMAT(now(), '%Y-%m-%d 00:00:00'), INTERVAL 30 DAY)
             from    dual
             where   not exists
                (select * from rslt_filter_item where rfs_id = p_RPT_SETUP_rfs_id and item_type = "meta_filter" and val_name = "filter_after_date" );
                
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_entry_tmplate_add`( 
   IN p_rpt_tmplt_name  varchar(255),
   IN p_render_name     varchar(255),
   IN p_entry_name      varchar(255),
   IN p_position_type   char(1),
   IN p_order_seq       smallint,
   IN p_qtype_name      varchar(255),
   IN p_rtype_name      varchar(255),  
   IN p_entry_type      char(4),
   IN p_format          varchar(255),
   IN p_counters        char(4),
   IN p_source_object   char(1),
   IN p_instruction     varchar(255)      
         )
stored_procedure:
begin
   declare v_re_id                int unsigned;
   declare v_rpt_tmplt_id         int unsigned;
   declare v_renderid             int unsigned;
   declare v_rtypeid              int unsigned;
   declare v_qtypeid              int unsigned;
   declare v_render_src_type      char(1);
   declare v_msg                   varchar(255);
   declare v_rows, v_err           int default 0;
   
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   
   select rpt_tmplt_id into v_rpt_tmplt_id
   from   report_template
   where  name = p_rpt_tmplt_name;
   
   set v_rows = ROW_COUNT();
   if v_rows != 1 then
      set @sp_return_stat = 1, v_msg = concat( 'rpt_entry_tmplate_add: unknown rpt name ', p_rpt_tmplt_name);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if; 
   
   if p_qtype_name is not null then
      
   select qtypeid  into v_qtypeid
   from   qtype
   where  title = p_qtype_name;
   
   set v_rows = ROW_COUNT();
      if v_rows != 1 then
         set @sp_return_stat = 1, v_msg = concat( 'rpt_entry_tmplate_add: unknown qtype name ', p_qtype_name );
          SIGNAL SQLSTATE '01000'
         SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
         leave stored_procedure; 
      end if; 
   end if;
   
   select rtypeid into v_rtypeid
   from   rtype
   where  rtype_name = p_rtype_name;
   
   set v_rows = ROW_COUNT();
   if v_rows != 1 then
      set @sp_return_stat = 1, v_msg = concat( 'rpt_entry_tmplate_add: unknown rtypet name ', p_rtype_name );
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if; 
   select renderid into v_renderid
   from   render_templates
   where  name = p_render_name;
   
   set v_rows = ROW_COUNT();
   if v_rows != 1 then
   
      if p_qtype_name is null then  
           set v_render_src_type = "C"; 
      else set v_render_src_type = "Q";
      end if;
      
      insert render_templates(name, template_file_name, src_type) 
                      values ( p_render_name, 'TBD', v_render_src_type );
      set v_renderid = LAST_INSERT_ID();
   
   end if; 
   insert report_entry_template 
          ( rpt_tmplt_id, renderid, name, position_type, order_seq, source_object, qtypeid, rtypeid, entry_type, format, counters, instruction )
   values ( v_rpt_tmplt_id, v_renderid, p_entry_name, p_position_type, p_order_seq, p_source_object, v_qtypeid, v_rtypeid, p_entry_type, p_format, p_counters, p_instruction);
   set @v_renderid = LAST_INSERT_ID();
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_establish_filter_set`( IN  p_rpid           integer unsigned,
          IN  p_uid            integer unsigned,
          IN  p_filter_name    varchar(255),
          IN  p_copy_rpt_owner tinyint unsigned,
          OUT p_user_rfs_id    integer unsigned
         )
stored_procedure:
begin
   declare v_rpt_owner_rfs_id,
           v_rpt_owner_uid   int unsigned;
   declare v_msg              varchar(255);
   declare v_rows, v_err    int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   select owner_uid into v_rpt_owner_uid 
   from   report
   where  rpid = p_rpid;
   SET v_rows = ROW_COUNT();
   
   if v_rows  != 1 then
      set @sp_return_stat = 1, v_msg = concat( 'rpt_establish_filter_set: rpid unknown = ', p_rpid);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;
   
   select rfs_id into p_user_rfs_id
   from   rslt_filter_set
   where  uid  = p_uid
   and    rpid = p_rpid
   and    name = p_filter_name;
   SET v_rows = ROW_COUNT();
   
   if v_rows = 0 then
      insert rslt_filter_set (rpid,   uid,   is_user, name) 
                      values (p_rpid, p_uid, 1,       p_filter_name);
      set p_user_rfs_id = LAST_INSERT_ID();
   end if;
   
   if v_rpt_owner_uid != p_uid and p_copy_rpt_owner = 1 then
      
      select rfs_id into v_rpt_owner_rfs_id
      from   rslt_filter_set
      where  uid  = v_rpt_owner_uid
      and    name = p_filter_name;
      
   
      delete from rslt_filter_item 
      where  rfs_id = p_user_rfs_id;
      insert rslt_filter_item
           ( rfs_id, active, item_type, qnid, rpatid, 
             val_name, val_type, val_I, val_T, val_S )
         select p_user_rfs_id, active, item_type, qnid, rpatid, 
                val_name, val_type, val_I, val_T, val_S 
         from   rslt_filter_item
         where  rfs_id = v_rpt_owner_rfs_id
         and    active = 1;
   end if;
   
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_FULL`( IN p_rpid      integer unsigned,
          IN p_uid       integer unsigned
         )
stored_procedure:
begin
   declare v_rpt_type               varchar(3);
   declare v_top_org_type           char(1);
   declare v_rpt_top_orgid          integer unsigned; 
   declare v_rpt_top_qnid           integer unsigned;
   
   declare v_survey_count           integer;
   declare v_RPT_SETUP_rfs_id       integer unsigned;
   declare v_RPT_ORG_RESULTS_rfs_id integer unsigned;
          
   declare v_msg                    varchar(255);
   declare v_rows, v_err            int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   call rpt_smry_prepare_env 
        ( p_rpid, p_uid,
          
          v_rpt_type, v_top_org_type, v_rpt_top_orgid, v_rpt_top_qnid, v_survey_count, 
          v_RPT_SETUP_rfs_id, v_RPT_ORG_RESULTS_rfs_id 
        );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   
   insert t_rpat_spec( rfs_id, collect_counts,
                       qnid, resgroup, rpatid, txt_validation, qid, eid1, eid2, eid3, score, rt_patid)
      select v_RPT_ORG_RESULTS_rfs_id as rfs_id, 
             1 as collect_all_ans,
             r.qnid, r.resgroup, r.rpatid, r.txt_validation, r.qid, r.eid1, r.eid2, r.eid3, r.score, r.rt_patid                                 
      from   t_rpt_survey  s,
             rslt_rpat_spec_setup r
      where  s.qnid = r.qnid;
  
   call rpt_smry_collect_counts
        ( v_top_org_type, v_rpt_top_qnid, v_RPT_SETUP_rfs_id, v_RPT_ORG_RESULTS_rfs_id 
        );
          
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   
   call rpt_smry_standard_output
        ( v_RPT_ORG_RESULTS_rfs_id,
          v_top_org_type,
          v_survey_count,
          v_rpt_top_qnid,
          1 
         );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_get_property_pick_list`( 
          IN  p_uid      integer unsigned,
          IN  p_rpt_type char(3)    -- use null when getting list for hot alerts
         )
stored_procedure:
begin
   declare v_orgid             integer unsigned;
   declare v_user_lngid        integer unsigned;
   declare v_rpid              integer unsigned;
   declare v_org_type          char(1);
   declare v_RPT_SETUP_rfs_id  integer unsigned;
   declare v_f_one_orgid       integer unsigned; -- filter
   declare v_f_org_rank_N      integer; -- Allow -ve/ -ve
                                   
   declare v_msg               varchar(255);
   declare v_rows, v_err       int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;   
   set @sp_return_stat = 0;
   
   select U.lngid, O.orgid, O.type into v_user_lngid, v_orgid, v_org_type
   from   users        U,
          organisation O
   where  U.orgid = O.orgid
   and    U.uid   = p_uid; 
   set v_rows = ROW_COUNT();
   if v_rows != 1 or v_org_type not in ("G", "A") then
      set @sp_return_stat = 1, v_msg = concat( 'rpt_get_property_pick_list: invalid uid/org type ', p_uid, " / ", v_org_type );
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if; 
   if p_rpt_type is not null then
      -- We only look for saved configuration via survey filters
      -- (ie Hot alert pick list will always give All)
      
      call rpt_ensure_scratchpad_report_setup( p_uid, p_rpt_type, null, v_rpid, v_RPT_SETUP_rfs_id);
         -- Determine what's selected (if it is atill valid!)
         -- if not default to all & remove filter item
      set v_f_one_orgid  = fltr_meta_item_get_I( v_RPT_SETUP_rfs_id, 'one_org' ), -- safe if multiple
          v_f_org_rank_N = fltr_meta_item_get_I( v_RPT_SETUP_rfs_id, 'org_rank_N' );
   end if;
   
   CREATE TEMPORARY TABLE IF NOT EXISTS t_org_pick_list( 
      seq           int unsigned not null auto_increment,
      orgid         int unsigned not null,
      action_type   char(1)      null,
      name          varchar(255) not null,
      list_top_bot  integer      null,
      picked        tinyint      null,
      primary key (seq)
      ) ENGINE=MEMORY;
   truncate table t_org_pick_list;
   -- language indepdant representations would be best
   -- or use v_user_lngid to below in correct language!
   insert t_org_pick_list( orgid, action_type, name, list_top_bot ) values
         ( v_orgid, "A", "All Properties",   null),
         ( v_orgid, "R", "Top  5 Properties",   5),
         ( v_orgid, "R", "Top 10 Properties",  10),
         ( v_orgid, "R", "Bottom 5  Properties",  -5),
         ( v_orgid, "R", "Bottom 10 Properties", -10);
 
   insert t_org_pick_list( orgid, action_type, name) 
      select R.c_orgid,
             R.c_type,
             R.c_name
      from   org_relation R
      where  R.p_orgid = v_orgid
      and    R.c_type  = 'S'
      -- and   c_active = 1 -- remove site from group to prevent reporting
      order by R.c_name;
 
    set v_rows = 0;
    
    if v_f_one_orgid is not null then
      -- support mutiple site pick
      update t_org_pick_list  P,
             rslt_filter_item I
      set    P.picked      = 1
      where  P.orgid       = I.val_I
      and    P.action_type = "S"
      and    I.rfs_id      = v_RPT_SETUP_rfs_id
      and    I.active      = 1
      and    I.item_type   = "meta_filter"
      and    I.val_type    = "I"
      and    I.val_name    = "one_org";
      
      set v_rows = ROW_COUNT();
 
   elseif v_f_org_rank_N is not null then
      update t_org_pick_list
      set    picked = 1
      where  list_top_bot = v_f_org_rank_N
      and    action_type  = "R";
      set v_rows = ROW_COUNT();
   end if;
 
   if v_rows  = 0 then
      update t_org_pick_list
      set    picked = 1
      where  name = "All Properties"; -- Language switch TBD.
      set v_rows = ROW_COUNT();
  
      -- inactivate  group setting that may have been invalidated e.g. by removing site from group
      if p_rpt_type is not null then 
         update rslt_filter_item 
         set    active = 0
         where rfs_id = v_RPT_SETUP_rfs_id 
         and   ( val_name = 'one_org' or  val_name like 'org_rank%' );
      end if;
   end if;
 
   -- List sites & options available to group 
   -- ordered to give general choices then sites alphabetical
   -- 
   select seq, orgid, action_type, name, list_top_bot, picked
   from t_org_pick_list
   order by seq;
   drop temporary table t_org_pick_list;
end$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_get_survey_structure`( 
          p_rpid   integer unsigned,
          p_lngid  tinyint unsigned,
          p_qnid   integer unsigned  -- set null to use latest, or override to historical when needed
        )
stored_procedure:
begin
   declare v_msg               varchar(255);
   declare v_rows, v_err       int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      drop temporary table if exists t_q_use;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   if p_qnid is null then
      select U.qnid into p_qnid 
      from   report R,
             survey_used U
      where  R.rpid    = p_rpid
      and    R.orgid   = U.orgid
      and    U.active  = 1
      and    U.date_end is null; -- latest survey 
      set v_rows = ROW_COUNT(); 
 
      if v_rows != 1 then
         set @sp_return_stat = 1, v_msg = concat( 'rpt_get_survey_structure: survey unclear for rpid ', p_rpid);
         SIGNAL SQLSTATE '01000'
         SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
         leave stored_procedure; 
      end if; 
   end if;
 
   -- identify useable question detail
   create temporary table t_q_use ENGINE=MEMORY as
      select
          P.pid, Q.qid, QRT.rtypeid,
          QT.title         as qtype, 
          P_LT.lang_text_S as p_title,
          Q_LT.lang_text_S as q_title
      from page P
      inner join  question Q
         on  P.pid      = Q.pid
      inner join  qtype QT
         on  Q.qtypeid  = QT.qtypeid
         and QT.title not in ("pres_image","pres_text" )
      inner join question_rtype QRT
         on Q.qid       = QRT.qid
      left outer join language_translation P_LT
         on  P_LT.obj_id = P.pid  
         and P_LT.lotid  = (select lotid from language_object_type where item_type = "page.title" )
         and P_LT.lngid  = p_lngid
      left outer join language_translation Q_LT
         on  Q.qid       = Q_LT.obj_id
         and Q_LT.lotid  = (select lotid from language_object_type where item_type = "question.title" )
         and Q_LT.lngid  = p_lngid
      where P.qnid       = p_qnid;
   -- (i) provide survey components with language translation where possible
   --
   select U.rtypeid   as q_rtypeid, Q.param_name as q_rtype_name, U.qtype, 
          P.order_seq as pid_seq,   Q.order_seq  as qid_seq,
          p_qnid, U.pid, U.qid,
          ifnull( U.p_title, P.title ) as p_title,
          ifnull( U.q_title, Q.title ) as q_title,
          --
          E.dimension as e_dim, E.order_seq as eid_seq, E.eid,
          E.type,  ifnull( E_LT.lang_text_S, E.name )as e_name
   from  t_q_use U
   inner join  question Q
      on  U.qid = Q.qid
   inner join  page P
      on U.pid  = P.pid
   inner join element E
      on Q.qid  = E.qid
   left outer join language_translation E_LT
      on  E.eid      = E_LT.obj_id
      and E_LT.lotid = (select lotid from language_object_type where item_type = "element.name" )
      and E_LT.lngid = p_lngid
   where P.qnid = p_qnid
   order by P.order_seq, Q.order_seq, E.dimension, E.order_seq;
   -- (ii) provide mappings to reporting answer patterns
   --
   select T.q_rtypeid, R.rtype_name  as q_rtype_name,  -- name for php debug
          P.rt_patid, P.type, U.qid, P.eid1, P.eid2, P.eid3
   from  t_q_use       U,
         respattern    P,
         rtype_pattern T,
         rtype         R
   where U.qid = P.qid
   and   P.rt_patid is not null -- Skip answers not fully mapped for report use
   and   P.rt_patid  = T.rt_patid
   and   T.q_rtypeid = R.rtypeid;
       
   drop temporary table if exists t_q_use;
    
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_identify_orgs_and_surveys`( IN  p_rpid                     integer unsigned,
          IN  p_uid                      integer unsigned,
          IN  p_RPT_SETUP_rfs_id         integer unsigned,
          IN  p_RPT_SETUP_FILTERS_rfs_id integer unsigned,
          OUT p_survey_count             integer,
          OUT p_rpt_org_latest_qnid      integer unsigned,
          OUT p_rpt_org_type             char(1)
         )
stored_procedure:
begin
   declare 
           v_rpt_top_orgid,
           v_one_orgid,
           v_org_rank_kpi_rtypeid,
           v_RPT_KPI_EVAL_rfs_id
                                   integer unsigned;
   declare v_org_rank_kpi_name     varchar(255);
   declare v_org_count             int;
   declare v_org_rank_N            int default 0;   
   declare v_msg                   varchar(255);
   declare v_rows, v_err           int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   select R.orgid, O.type into v_rpt_top_orgid, p_rpt_org_type
   from   report R,
          organisation O
   where  R.rpid  = p_rpid
   and    R.orgid = O.orgid;
   set v_rows = ROW_COUNT();
   if v_rows != 1 then
      set @sp_return_stat = 1, v_msg = concat( 'rpt_identify_orgs_and surveys: unknown rpid ', p_rpid);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if; 
   set v_one_orgid            = fltr_meta_item_get_I( p_RPT_SETUP_rfs_id, 'one_org' ), -- pick safe if multiple!
       v_org_rank_N           = fltr_meta_item_get_I( p_RPT_SETUP_rfs_id, 'org_rank_N' ),
       v_org_rank_kpi_name    = fltr_meta_item_get_S( p_RPT_SETUP_rfs_id, 'org_rank_kpi' ); 
    insert t_rpt_org ( orgid, org_type ) values ( v_rpt_top_orgid, p_rpt_org_type );
    set v_org_count = 1;
    -- Adding in child sites
    if ( p_rpt_org_type = "G" or p_rpt_org_type = "A" ) then
      if v_one_orgid is null then
         insert t_rpt_org ( orgid, org_type )
            select c_orgid, c_type
            from   org_relation
            where  p_orgid  = v_rpt_top_orgid
            and    c_type   = "S";
            -- and    p_active = 1 -- Let reporting control be just survey_used.active
            -- and    c_active = 1
         set v_rows = ROW_COUNT();
      else
         -- Support pick of multiple identified sites
         insert t_rpt_org ( orgid, org_type )
            select R.c_orgid, R.c_type
            from   org_relation R,
                   rslt_filter_item I
            where  R.p_orgid   = v_rpt_top_orgid
            and    R.c_type    = "S"
            and    I.rfs_id    = p_RPT_SETUP_rfs_id
            and    I.active    = 1
            and    I.item_type = "meta_filter"
            and    I.val_type  = "I"
            and    I.val_name  = "one_org"
            and    R.c_orgid   = I.val_I;
         set v_rows = ROW_COUNT();
      end if; 
         
      set v_org_count = v_org_count + ROW_COUNT();
   end if;
   insert t_rpt_survey( orgid, org_type, qnid, date_start, date_end )
      select G.orgid, G.org_type, U.qnid, date_start, date_end
      from  survey_used U,
            t_rpt_org G
      where G.orgid  = U.orgid
      and   U.active = 1;
      --    G.org_type = "S"  --  Higher sites have no survey results 
      --    date_end is null  -- initially just latest survey for each org
   set p_survey_count = ROW_COUNT();
   
   select qnid into p_rpt_org_latest_qnid
   from   t_rpt_survey 
   where  orgid = v_rpt_top_orgid
   and    date_end is null;
   set v_rows = ROW_COUNT();
   if v_rows != 1 then
      set @sp_return_stat = 1, v_msg = concat( 'rpt_identify_orgs_and surveys: latest qnid unknown for rpid=', p_rpid);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;
   if v_one_orgid > 0 or v_org_rank_N is null 
      or v_org_count <= ifnull( abs(v_org_rank_N) , v_org_count ) 
   then
      leave stored_procedure; 
   end if;
   -- ------------------------------------------------------------------  
   -- TOP N / BOT N ORG REBUILD
   -- ------------------------------------------------------------------  
   --
   -- Re-work to a smaller set of orgs by collecting ordered KPI scores 
   -- for each org to refine content of t_rpt_org & t_rpt_survey
   call rpt_establish_filter_set (
          p_rpid,         -- IN p_rpid 
          p_uid,          -- IN p_uid
          "RPT_KPI_EVAL", -- IN p_filter_name 
          0,              -- IN p_copy_rpt_owner,
          v_RPT_KPI_EVAL_rfs_id -- OUT p_user_rfs_id
          );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
 
   select rtypeid into v_org_rank_kpi_rtypeid  
   from   rtype
   where  rtype_name = v_org_rank_kpi_name;
   set v_rows = ROW_COUNT();
   if v_rows != 1 or
      v_org_rank_kpi_name not in ( "Q_NET_PROMOTER", "KPI_M_OVERALL_SAT", "KPI_M_VALUE_FOR_MONEY", "KPI_M_WOULD_RECOMMEND" )
   then
      set @sp_return_stat = 1, v_msg = concat( 'rpt_identify_orgs_and surveys: unknown kpi =', v_org_rank_kpi_name);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;
   
   -- Request counts on all patterns associated to KPI to score across surveys
   --
   if v_org_rank_kpi_name = "Q_NET_PROMOTER" then
      -- negative: 0 -> 6
      -- neutral:  7 -> 8
      -- positive: 9 -> 10
      insert t_rpat_spec( rfs_id, qnid, resgroup, collect_counts, 
                         rpatid, txt_validation, qid, eid1, eid2, eid3, score, rt_patid)
         select v_RPT_KPI_EVAL_rfs_id as rfs_id, -- global verse to all veses specific?
                p.qnid,
                qt.resgroup,
                case  sign( v_org_rank_N )
                when 1 then
                   case rp.score           when 9 then 1 when 10 then 1 else 0 end
                when -1 then
                   case sign(rp.score - 7) when -1 then 1 else 0 end
                end as collect_counts,
                rp.rpatid,
                q.txt_validation,
                q.qid, rp.eid1, rp.eid2, rp.eid3, rp.score,
                rp.rt_patid                                 
         from   t_rpt_survey  s,
                page          p,
                question      q,
                qtype         qt,
                respattern    rp
         where  s.qnid    = p.qnid
         and    p.pid     = q.pid
         and    q.qtypeid = qt.qtypeid
         and    q.qid     = rp.qid
         and rp.rt_patid in 
            ( select rt_patid
              from   rslt_rtype_pattern R
              where  R.q_rtypeid  = v_org_rank_kpi_rtypeid -- radio net promoter
             );
   else  -- MAIN_KPI scoring system
      insert t_rpat_spec( rfs_id, qnid, resgroup, collect_counts, 
                         rpatid, txt_validation, qid, eid1, eid2, eid3, score, rt_patid)
         select v_RPT_KPI_EVAL_rfs_id as rfs_id, -- global verse to all veses specific?
                p.qnid,
                qt.resgroup,
                -- positive negative needs extra on net promoter
                case  sign( v_org_rank_N )
                when 1 then
                   case rp.score when 5 then 1 when 4 then 1 else 0 end 
                when -1 then
                   case rp.score when 1 then 1 when 2 then 1 else 0 end
                end as collect_counts,
                rp.rpatid,
                q.txt_validation,
                q.qid, rp.eid1, rp.eid2, rp.eid3, rp.score,
                rp.rt_patid                                 
         from   t_rpt_survey  s,
                page          p,
                question      q,
                qtype         qt,
                respattern    rp
         where  s.qnid    = p.qnid
         and    p.pid     = q.pid
         and    q.qtypeid = qt.qtypeid
         and    q.qid     = rp.qid
         and    rp.rt_patid in 
            ( select rt_patid
              from   rslt_rtype_pattern R
              where  R.e1_rtypeid = v_org_rank_kpi_rtypeid -- matrix KPI questions
             );
   end if;
   
   -- Copy users filter choices in
   call rpt_setup_survey_filters ( p_rpt_org_type, p_RPT_SETUP_rfs_id, v_RPT_KPI_EVAL_rfs_id );
 
   -- There is a limit to what filters can be carried through from users
   -- without conflict/overlap with KPI scoring, so reduce
   -- Remove any overlap with KPI about to be ranked
   -- 
   delete I
   from   rslt_filter_item I,
          t_rpat_spec      S
   where  I.rfs_id    = v_RPT_KPI_EVAL_rfs_id
   and    I.item_type = "rpatid"
   and    I.rpatid    = S.rpatid
   and    S.rfs_id    = v_RPT_KPI_EVAL_rfs_id;
   -- intentionally no ref to collect counts!
  -- also remove filter options that are not needed in this evaluation
   delete from   rslt_filter_item 
   where  rfs_id    = v_RPT_KPI_EVAL_rfs_id
   and    item_type = "meta_filter"
   and    val_name in ( "date_group", "filter_mode", 
                        "org_rank_kpi", "org_rank_N" -- just for clarity!
                      );
   -- Filter to get needed KPI answers only ie the postive/negative rids in each survey
   -- 
   -- If a survey has incompatible/incomplete KPI compared to top survey
   -- it won't fully evaulate which is more forgiving than sp "rpt_setup_survey_filters" validation
   --
   insert rslt_filter_item ( rfs_id, active, item_type, qnid, rpatid, val_type )
      select v_RPT_KPI_EVAL_rfs_id, 1, "rpatid", rs.qnid, rs.rpatid, "I"     
      from   t_rpat_spec rs
      where  rs.rfs_id      = v_RPT_KPI_EVAL_rfs_id
      and    collect_counts = 1;
   set v_rows = ROW_COUNT();
   
   -- select * from t_rpat_spec where rfs_id = v_RPT_KPI_EVAL_rfs_id and  collect_counts = 1 order by rpatid;
   -- select * from rslt_filter_item where rfs_id = v_RPT_KPI_EVAL_rfs_id and item_type = "rpatid" order by rpatid;
   call rslt_build_filtered_rid_list( p_rpt_org_latest_qnid, v_RPT_KPI_EVAL_rfs_id );
   
   call rslt_build_clicks( v_RPT_KPI_EVAL_rfs_id, 0 );  -- p_include_empty_results  
   if @sp_debug = 1 then
      -- Show if KPI filters are same for each qnid, 
      select "DEBUG:rpt_identify_orgs_and_surveys filters per survey", qnid, count(*)
      from   t_rpat_spec
      where  rfs_id = v_RPT_KPI_EVAL_rfs_id
      and    collect_counts = 1
      group by qnid;
   
      -- show score summary & detail
      select "rpt_identify_orgs_and_surveys(smry)" as sp_dbg, rs.orgid, O.name, rs.org_type, rc.qnid, sum(rc.clicks * rp.score)
      from   t_rslt_count rc,
             respattern   rp,
             t_rpt_survey rs,
             organisation O
      where  rc.typ    =  "CNT"
      and    rc.rfs_id = v_RPT_KPI_EVAL_rfs_id
      and    rc.rpatid = rp.rpatid
      and    rc.qnid   = rs.qnid
      and    rs.orgid = O.orgid
      group by rs.orgid,  O.name, rs.org_type, rc.qnid 
      order by sum(rc.clicks * rp.score);
      select "rpt_identify_orgs_and_surveys(detail)" as sp_dbg, rs.orgid, O.name, rs.org_type, rc.qnid, q,e1,e2,rp.score, rc.clicks 
      from   t_rslt_count rc,
             respattern   rp,
             t_rpt_survey rs,
             rslt_rtype_pattern rt,
             organisation O
      where  rc.typ    =  "CNT"
      and    rc.rfs_id = v_RPT_KPI_EVAL_rfs_id
      and    rc.rpatid = rp.rpatid
      and    rc.qnid   = rs.qnid
      and    rp.rt_patid = rt.rt_patid
      and    rs.orgid = O.orgid
      order by rs.orgid, rc.qnid;
   end if;
   -- Use total scores per site to repopulate t_rpt_org & t_rpt_survey
   delete from t_rpt_org where org_type = "S";
   case sign(v_org_rank_N)
   when 1 then
      insert t_rpt_org ( orgid, org_type )
         select rs.orgid, rs.org_type
         from   t_rslt_count rc,
                respattern   rp,
                t_rpt_survey rs
         where  rc.typ    =  "CNT"
         and    rc.rfs_id = v_RPT_KPI_EVAL_rfs_id
         and    rc.rpatid = rp.rpatid
         and    rc.qnid   = rs.qnid
         group by rs.orgid, rs.org_type
         order by sum(rc.clicks * rp.score) desc limit v_org_rank_N; -- Highest N
   when -1 then
      
      set v_org_rank_N = abs(v_org_rank_N); -- to aid limit of rows
      
      insert t_rpt_org ( orgid, org_type )
         select rs.orgid, rs.org_type
         from   t_rslt_count rc,
                respattern   rp,
                t_rpt_survey rs
         where  rc.typ    =  "CNT"
         and    rc.rfs_id = v_RPT_KPI_EVAL_rfs_id
         and    rc.rpatid = rp.rpatid
         and    rc.qnid   = rs.qnid
         group by rs.orgid, rs.org_type
         order by sum(rc.clicks * rp.score) asc limit v_org_rank_N;  -- Lowest N
   end case;
   delete from t_rpt_survey where org_type = "S";
   
   insert t_rpt_survey( orgid, org_type, qnid, date_start, date_end )
      select G.orgid, G.org_type, U.qnid, date_start, date_end
      from  survey_used U,
            t_rpt_org G
      where G.orgid  = U.orgid
      and   U.active = 1
      and   G.org_type = "S";
      --   date_end is null; -- initially just latest survey for each org
       
   set p_survey_count = ROW_COUNT();
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_INDIVIDUAL`( IN p_rpid      integer unsigned,
          IN p_uid       integer unsigned
         )
stored_procedure:
begin
   declare v_rpt_type               varchar(3);
   declare v_top_org_type           char(1);
   declare v_rpt_top_orgid          integer unsigned; 
   declare v_rpt_top_qnid           integer unsigned;
   --
   declare v_survey_count           integer;
   declare v_RPT_SETUP_rfs_id       integer unsigned;
   declare v_RPT_ORG_RESULTS_rfs_id integer unsigned;
   --
   declare v_pos_neg_clicks         integer unsigned;
   declare v_total_clicks           integer unsigned;
   declare v_msg                    varchar(255);
   declare v_rows, v_err            int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   call rpt_smry_prepare_env 
        ( p_rpid, p_uid,
          -- OUT
          v_rpt_type, v_top_org_type, v_rpt_top_orgid, v_rpt_top_qnid, v_survey_count, 
          v_RPT_SETUP_rfs_id, v_RPT_ORG_RESULTS_rfs_id 
        );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   -- CUSTOM FILTER & COLLECTION NEEDS GO HERE
   insert t_rpat_spec( rfs_id, collect_counts,
                       qnid, resgroup, rpatid, txt_validation, qid, eid1, eid2, eid3, score, rt_patid)         
      select v_RPT_ORG_RESULTS_rfs_id as rfs_id, 
             0 as collect_all_ans, -- ZERO, only need rids, not smry
             r.qnid, r.resgroup, r.rpatid, r.txt_validation, r.qid, r.eid1, r.eid2, r.eid3, r.score, r.rt_patid 
      from   rslt_rpat_spec_setup r  
      where  r.qid in
       ( select distinct q.qid -- limit this to the KPI questions across the surveys
         from   t_rpt_survey   s,
                page           p,
                question       q,
                question_rtype qr,
                rtype q_rt
         where org_type   = "S"
         and   s.qnid     = p.qnid
         and   p.pid      = q.pid
         and   q.qid      = qr.qid
         and   qr.rtypeid = q_rt.rtypeid
         and (  (r.type = "NN" and  q_rt.rtype_name = "Q_KPI_MAIN") 
             or (r.type = "N"  and  q_rt.rtype_name = "Q_NET_PROMOTER")  -- new recomend
              )
        );
   -- Instead of filtering , last 20 rids approach requested Feb 2014
   
   -- The report setup filters should contain the radio elements for KPI pos, neg or neutral answers
   -- and the date range
   -- call rpt_smry_collect_counts( v_top_org_type, v_rpt_top_qnid, v_RPT_SETUP_rfs_id, v_RPT_ORG_RESULTS_rfs_id   );         
   -- if @sp_return_stat = 1 then leave stored_procedure; end if;
   -- manually identify results outside of normal filtering
   insert t_rids(qnid, grouping, rfs_id, rid )
      select R.qnid, null, v_RPT_ORG_RESULTS_rfs_id, R.rid
      from   t_rpt_survey S,
             rids R
      where  S.orgid  =  R.orgid
      and    S.qnid   =  R.qnid
      and    R.status = 1
      order by R.last_update desc   -- sort cost
      limit 20;
   -- classify KPI on results for the 20 rids to ease final joins
   drop temporary table if exists t_kpi_score;
   create temporary table t_kpi_score ENGINE=MEMORY
       select A.rid, S.score, P.e1 -- S.rt_patid
       from        t_rids      A,
                   result      R,
                   t_rpat_spec S,
                   rslt_rtype_pattern P
       where  A.rid    = R.rid
       and    R.rpatid = S.rpatid
       and    S.rfs_id = v_RPT_ORG_RESULTS_rfs_id
       and    S.rt_patid = P.rt_patid;
   -- can't do multiple join to temporary table :-( so forced to use group by
   -- if more time app should work with more vertical format to avoid this
   select B.rid, B.last_update, B.name, B.email, 
          max( case S.e1 when "KPI_M_WOULD_RECOMMEND" then S.score else null end ) as KPI_M_WOULD_RECOMMEND,
          max( case S.e1 when "KPI_M_VALUE_FOR_MONEY" then S.score else null end ) as KPI_M_VALUE_FOR_MONEY,
          max( case S.e1 when "KPI_M_OVERALL_SAT"     then S.score else null end ) as KPI_M_OVERALL_SAT,
          max( case substr(S.e1,1,7) when "ANS_NP_"   then S.score else null end ) as Q_NET_PROMOTER,
          B.qnid
   from        t_rids      A
   inner join  rids        B
      on A.rid    = B.rid
   left outer join t_kpi_score S
      on  A.rid = S.rid
   group by B.rid; -- , B.last_update, B.name, B.email;
/*
   select B.rid, B.last_update, B.name, B.email, 
          null as KPI_M_WOULD_RECOMMEND,
          V.score  as KPI_M_VALUE_FOR_MONEY,
          S.score  as KPI_M_OVERALL_SAT,
          null as Q_NET_PROMOTER
   from        t_rids      A
   inner join  rids        B
      on A.rid    = B.rid
   left outer join t_kpi_score V
      on  A.rid = V.rid
      and V.e1 = "KPI_M_VALUE_FOR_MONEY"
   left outer join t_kpi_score S
      on  A.rid = S.rid
      and S.e1 = "KPI_M_OVERALL_SAT"
      -- and V.e1 = "KPI_M_WOULD_RECOMMEND"
      -- e1 = like "ANS_NP%"
 */
   drop temporary table if exists t_kpi_score;
   
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_INDIVIDUAL_php`( IN p_rpid          integer unsigned,
          IN p_uid           integer unsigned,
          -- Note use meta filter "email" if required
          IN p_row_offset    integer unsigned,
          IN p_row_limit     integer unsigned,
          OUT p_found_rows   integer unsigned
         )
stored_procedure:
begin
   declare v_rpt_type               varchar(3);
   declare v_top_org_type           char(1);
   declare v_rpt_top_orgid          integer unsigned; 
   declare v_rpt_top_qnid           integer unsigned;
   --
   declare v_survey_count           integer;
   declare v_RPT_SETUP_rfs_id       integer unsigned;
   declare v_RPT_ORG_RESULTS_rfs_id integer unsigned;
   --
   declare v_pos_neg_clicks         integer unsigned;
   declare v_total_clicks           integer unsigned;
   declare v_msg                    varchar(255);
   declare v_rows, v_err            int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   call rpt_smry_prepare_env 
        ( p_rpid, p_uid,
          -- OUT
          v_rpt_type, v_top_org_type, v_rpt_top_orgid, v_rpt_top_qnid, v_survey_count, 
          v_RPT_SETUP_rfs_id, v_RPT_ORG_RESULTS_rfs_id 
        );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   -- CUSTOM FILTER & COLLECTION NEEDS GO HERE
   insert t_rpat_spec( rfs_id, collect_counts,
                       qnid, resgroup, rpatid, txt_validation, qid, eid1, eid2, eid3, score, rt_patid)         
      select v_RPT_ORG_RESULTS_rfs_id as rfs_id, 
             0 as collect_all_ans, -- ZERO, only need rids, not smry
             r.qnid, r.resgroup, r.rpatid, r.txt_validation, r.qid, r.eid1, r.eid2, r.eid3, r.score, r.rt_patid 
      from   rslt_rpat_spec_setup r  
      where  r.qid in
       ( select distinct q.qid -- limit this to the KPI questions across the surveys
         from   t_rpt_survey   s,
                page           p,
                question       q,
                question_rtype qr,
                rtype q_rt
         where org_type   = "S"
         and   s.qnid     = p.qnid
         and   p.pid      = q.pid
         and   q.qid      = qr.qid
         and   qr.rtypeid = q_rt.rtypeid
         and (  (r.type = "NN" and  q_rt.rtype_name = "Q_KPI_MAIN") 
             or (r.type = "N"  and  q_rt.rtype_name = "Q_NET_PROMOTER")  -- new recomend
              )
        );
   -- Instead of filtering , last 20 rids approach requested Feb 2014
   
   -- The report setup filters should contain the radio elements for KPI pos, neg or neutral answers
   -- and the date range
   -- New requiremnt is to search on email of user
   call rpt_smry_collect_counts( v_top_org_type, v_rpt_top_qnid, v_RPT_SETUP_rfs_id, v_RPT_ORG_RESULTS_rfs_id   );         
   if @sp_return_stat = 1 then leave stored_procedure; end if;
/* 20 rid limit requirement no longer required
   -- manually identify results outside of normal filtering
   insert t_rids(qnid, grouping, rfs_id, rid )
      select R.qnid, null, v_RPT_ORG_RESULTS_rfs_id, R.rid
      from   t_rpt_survey S,
             rids R
      where  S.orgid  =  R.orgid
      and    S.qnid   =  R.qnid
      and    R.status = 1
      order by R.last_update desc   -- sort cost
      limit 20;
   -- classify KPI on results for the 20 rids to ease final joins
*/
   drop temporary table if exists t_kpi_score;
   create temporary table t_kpi_score ENGINE=MEMORY
       select A.rid, S.score, P.e1 -- S.rt_patid
       from        t_rids      A,
                   result      R,
                   t_rpat_spec S,
                   rslt_rtype_pattern P
       where  A.rid    = R.rid
       and    R.rpatid = S.rpatid
       and    S.rfs_id = v_RPT_ORG_RESULTS_rfs_id
       and    S.rt_patid = P.rt_patid;
       
   if @sp_debug = 2 then
     select * from t_rids;
   end if;
   
 
   -- using group by as no multiple join to temporary table 
   -- introduced slicing of results returned for presentation .  Above KPI collecton for all is overhead
   -- if more time app should work with more vertical format to avoid this, but would need to factor in slicing
   select SQL_CALC_FOUND_ROWS
          B.rid, B.last_update, B.name, B.email, 
          max( case S.e1 when "KPI_M_WOULD_RECOMMEND" then S.score else null end ) as KPI_M_WOULD_RECOMMEND,
          max( case S.e1 when "KPI_M_VALUE_FOR_MONEY" then S.score else null end ) as KPI_M_VALUE_FOR_MONEY,
          max( case S.e1 when "KPI_M_OVERALL_SAT"     then S.score else null end ) as KPI_M_OVERALL_SAT,
          max( case substr(S.e1,1,7) when "ANS_NP_"   then S.score else null end ) as Q_NET_PROMOTER,
          B.qnid
   from        t_rids      A
   inner join  rids        B
      on A.rid    = B.rid
   left outer join t_kpi_score S
      on  A.rid = S.rid
   group by B.rid  -- , B.last_update, B.name, B.email;
   order by B.last_update desc
   limit  p_row_offset, p_row_limit;
   set p_found_rows = FOUND_ROWS();
/*
   select B.rid, B.last_update, B.name, B.email, 
          null as KPI_M_WOULD_RECOMMEND,
          V.score  as KPI_M_VALUE_FOR_MONEY,
          S.score  as KPI_M_OVERALL_SAT,
          null as Q_NET_PROMOTER
   from        t_rids      A
   inner join  rids        B
      on A.rid    = B.rid
   left outer join t_kpi_score V
      on  A.rid = V.rid
      and V.e1 = "KPI_M_VALUE_FOR_MONEY"
   left outer join t_kpi_score S
      on  A.rid = S.rid
      and S.e1 = "KPI_M_OVERALL_SAT"
      -- and V.e1 = "KPI_M_WOULD_RECOMMEND"
      -- e1 = like "ANS_NP%"
 */
   drop temporary table if exists t_kpi_score;
   
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_LEAGUE`( IN p_rpid      integer unsigned,
          IN p_uid       integer unsigned
         )
stored_procedure:
begin
   declare v_rpt_type               varchar(3);
   declare v_top_org_type           char(1);
   declare v_rpt_top_orgid          integer unsigned; 
   declare v_rpt_top_qnid           integer unsigned;
   
   declare v_survey_count           integer;
   declare v_RPT_SETUP_rfs_id       integer unsigned;
   declare v_RPT_ORG_RESULTS_rfs_id integer unsigned;
   
   declare v_pos_neg_clicks         integer unsigned;
   declare v_total_clicks           integer unsigned;
   declare v_msg                    varchar(255);
   declare v_rows, v_err            int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   call rpt_smry_prepare_env 
        ( p_rpid, p_uid,
          
          v_rpt_type, v_top_org_type, v_rpt_top_orgid, v_rpt_top_qnid, v_survey_count, 
          v_RPT_SETUP_rfs_id, v_RPT_ORG_RESULTS_rfs_id 
        );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   
   
   insert t_rpat_spec( rfs_id, collect_counts,
                       qnid, resgroup, rpatid, txt_validation, qid, eid1, eid2, eid3, score, rt_patid)         
      select v_RPT_ORG_RESULTS_rfs_id as rfs_id, 
             1 as collect_all_ans,
             r.qnid, r.resgroup, r.rpatid, r.txt_validation, r.qid, r.eid1, r.eid2, r.eid3, r.score, r.rt_patid 
      from   rslt_rpat_spec_setup r  
      where  r.qid in
       ( select distinct q.qid 
         from   t_rpt_survey   s,
                page           p,
                question       q,
                question_rtype qr,
                rtype q_rt
         where org_type   = "S"
         and   s.qnid     = p.qnid
         and   p.pid      = q.pid
         and   q.qid      = qr.qid
         and   qr.rtypeid = q_rt.rtypeid
         and (  (r.type = "NN" and  q_rt.rtype_name = "Q_KPI_MAIN") 
             or (r.type = "N"  and  q_rt.rtype_name = "Q_NET_PROMOTER")  
              )
        );
        
   call rpt_smry_collect_counts
        ( v_top_org_type, v_rpt_top_qnid, v_RPT_SETUP_rfs_id, v_RPT_ORG_RESULTS_rfs_id 
        );         
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   
   
   
   
   select "kpi_scores" as data_set,
          org.name,   
          rt.rtype_name,
          sign(rp.score - 3) as grp,
          sum(rc.clicks) as clicks
   from   organisation  org,
          t_rpt_survey  sy,
          t_rslt_count  rc,
          respattern    rp,
          rtype_pattern tp,
          rtype         rt
   where  org.orgid     = sy.orgid
   and    org.type      = "S"
   and    sy.qnid       = rc.qnid
   and    rc.rfs_id     = v_RPT_ORG_RESULTS_rfs_id
   and    rc.typ        = "CNT"
   and    rc.rpatid     = rp.rpatid
   and    rp.rt_patid   = tp.rt_patid
   and    tp.e1_rtypeid = rt.rtypeid 
   and    rt.rtype_name in 
          
          ( "KPI_M_OVERALL_SAT","KPI_M_VALUE_FOR_MONEY", "KPI_M_WOULD_RECOMMEND" )
   and    rp.score >= 1 and rp.score <= 5
   group by rc.grouping, rt.rtype_name, sign(rp.score - 3);
   
   
   
   
   
   
   select "kpi_NP_scores" as data_set,
           rc.grouping,
           rt.rtype_name,
           case rp.score when 10 then 1 when 9 then 1 
                         when  8 then 0 when 7 then 0 
                         else -1 end as grp,
           sum(rc.clicks) as clicks
   from   t_rslt_count  rc,
          respattern    rp,
          rtype_pattern tp,
          rtype         rt
   where  rc.rfs_id     = v_RPT_ORG_RESULTS_rfs_id
   and    rc.typ        = "CNT"
   and    rc.rpatid     = rp.rpatid
   and    rp.rt_patid   = tp.rt_patid
   and    tp.q_rtypeid = rt.rtypeid 
   and    rt.rtype_name = "Q_NET_PROMOTER"
   and    rp.score >= 0 and rp.score <= 10
   group by rc.grouping, rt.rtype_name, 
            case rp.score when 10 then 1 when 9 then 1 when 8 then 0 when 7 then 0 else -1 end;
   select "kpi_responses" as data_set,
          org.name,   
          rc.typ, 
          sum(rc.rids) as rids
   from  organisation  org,
         t_rpt_survey  sy,
         t_rslt_count  rc
   where org.orgid     = sy.orgid
   and   org.type      = "S"
   and   sy.qnid = rc.qnid
   and   typ in ("fltr_completed_rids", "smry_completed_rids" , "smry_no_reply_rids" )
   and   rc.rfs_id = v_RPT_ORG_RESULTS_rfs_id
   group by org.name, rc.typ;
    
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_list_reports`( IN  p_uid       integer unsigned,
          IN  p_rpt_type  char(3) -- use null for all
         )
stored_procedure:
begin
   declare v_msg                    varchar(255);
   declare v_rows, v_err            int default 0;
   
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
/*
   select owner_uid into v_old_owner_uid
   from report where rpid = p_old_rpid;
   set v_rows = ROW_COUNT();
   
   if v_rows != 1 then
      set @sp_return_stat = 1, v_msg = concat( 'rpt_list_reports: not found rpid ', p_old_rpid);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;
*/
   -- if @sp_debug = 1 then ; end if;
   select R.owner_uid, S.first_name, S.last_name, 
          case O.uid when owner_uid then "Y" else "N" end as overwrite_allow, 
          R.rpid, R.rpt_type, R.shared, R.name
   from  report R,
         users  O, -- For org of user
         users  S  -- Rpt owner
   where O.uid      = p_uid
   and   O.orgid    = R.orgid 
   and   R.rpt_type = ifnull( p_rpt_type, R.rpt_type)
   and   R.is_user  = 1 
   and ( R.owner_uid = O.uid or R.shared = 1 )
   and   R.owner_uid = S.uid;
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_MAIN`( IN p_rpid      integer unsigned,
          IN p_uid       integer unsigned
         )
stored_procedure:
begin
   declare v_rpt_type               varchar(3);
   declare v_top_org_type           char(1);
   declare v_rpt_top_orgid          integer unsigned; 
   declare v_rpt_top_qnid           integer unsigned;
   
   declare v_survey_count           integer;
   declare v_RPT_SETUP_rfs_id       integer unsigned;
   declare v_RPT_ORG_RESULTS_rfs_id integer unsigned;
          
   declare v_msg                    varchar(255);
   declare v_rows, v_err            int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   call rpt_smry_prepare_env 
        ( p_rpid, p_uid,
          
          v_rpt_type, v_top_org_type, v_rpt_top_orgid, v_rpt_top_qnid, v_survey_count, 
          v_RPT_SETUP_rfs_id, v_RPT_ORG_RESULTS_rfs_id 
        );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
 
   
      
 
    insert t_rpat_spec( rfs_id, collect_counts,
                       qnid, resgroup, rpatid, txt_validation, qid, eid1, eid2, eid3, score, rt_patid)         
      select v_RPT_ORG_RESULTS_rfs_id as rfs_id, 
             1 as collect_all_ans,
             r.qnid, r.resgroup, r.rpatid, r.txt_validation, r.qid, r.eid1, r.eid2, r.eid3, r.score, r.rt_patid 
      from   rslt_rpat_spec_setup r  
      where  r.qid in
       ( select distinct q.qid 
         from   t_rpt_survey   s,
                page           p,
                question       q,
                question_rtype qr,
                rtype q_rt
         where org_type   = "S"
         and   s.qnid     = p.qnid
         and   p.pid      = q.pid
         and   q.qid      = qr.qid
         and   qr.rtypeid = q_rt.rtypeid
         
         and   q_rt.rtype_name in
         ( "Q_KPI_MAIN",  "Q_NET_PROMOTER",
           "Q_KPI_RECEPTION_AND_PROPERTY",
           "Q_OK_TO_ASK_QUESTIONS", 
           "Q_WHERE_FROM",
           "Q_NIGHTS_SPENT",  
           "Q_ALREADY_VISTED",
           "Q_HOW_HEAR_OF_US", 
           "Q_REASON_FOR_VISIT"
         ) );
         
   call rpt_smry_collect_counts
        ( v_top_org_type, v_rpt_top_qnid, v_RPT_SETUP_rfs_id, v_RPT_ORG_RESULTS_rfs_id 
        );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   
   call rpt_smry_standard_output
        ( v_RPT_ORG_RESULTS_rfs_id,
          v_top_org_type,
          v_survey_count,
          v_rpt_top_qnid,
          0 
         );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_OVERVIEW`( IN p_rpid      integer unsigned,
          IN p_uid       integer unsigned
         )
stored_procedure:
begin
   declare v_rpt_type               varchar(3);
   declare v_top_org_type           char(1);
   declare v_rpt_top_orgid          integer unsigned; 
   declare v_rpt_top_qnid           integer unsigned;
   
   declare v_survey_count           integer;
   declare v_RPT_SETUP_rfs_id       integer unsigned;
   declare v_RPT_ORG_RESULTS_rfs_id integer unsigned;
   
   declare v_pos_neg_clicks         integer unsigned;
   declare v_total_clicks           integer unsigned;
   declare v_msg                    varchar(255);
   declare v_rows, v_err            int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   call rpt_smry_prepare_env 
        ( p_rpid, p_uid,
          
          v_rpt_type, v_top_org_type, v_rpt_top_orgid, v_rpt_top_qnid, v_survey_count, 
          v_RPT_SETUP_rfs_id, v_RPT_ORG_RESULTS_rfs_id 
        );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   
   
   insert t_rpat_spec( rfs_id, collect_counts,
                       qnid, resgroup, rpatid, txt_validation, qid, eid1, eid2, eid3, score, rt_patid)         
      select v_RPT_ORG_RESULTS_rfs_id as rfs_id, 
             1 as collect_all_ans,
             r.qnid, r.resgroup, r.rpatid, r.txt_validation, r.qid, r.eid1, r.eid2, r.eid3, r.score, r.rt_patid 
      from   rslt_rpat_spec_setup r  
      where  r.qid in
       ( select distinct q.qid 
         from   t_rpt_survey   s,
                page           p,
                question       q,
                question_rtype qr,
                rtype q_rt
         where org_type   = "S"
         and   s.qnid     = p.qnid
         and   p.pid      = q.pid
         and   q.qid      = qr.qid
         and   qr.rtypeid = q_rt.rtypeid
         and (  (r.type = "NN" and  q_rt.rtype_name = "Q_KPI_MAIN") 
             or (r.type = "N"  and  q_rt.rtype_name = "Q_NET_PROMOTER")  
              )
        );
         
   
   
   
   call rpt_smry_collect_counts
        ( v_top_org_type, v_rpt_top_qnid, v_RPT_SETUP_rfs_id, v_RPT_ORG_RESULTS_rfs_id 
        );         
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   
   
   
   
   select "kpi_scores" as data_set,
           rc.grouping,
           rt.rtype_name,
           sign(rp.score - 3) as grp,
           sum(rc.clicks) as clicks
           
   from   t_rslt_count  rc,
          respattern    rp,
          rtype_pattern tp,
          rtype         rt
   where  rc.rfs_id     = v_RPT_ORG_RESULTS_rfs_id
   and    rc.typ        = "CNT"
   and    rc.rpatid     = rp.rpatid
   and    rp.rt_patid   = tp.rt_patid
   and    tp.e1_rtypeid = rt.rtypeid 
   and    rt.rtype_name in 
          
          ( "KPI_M_OVERALL_SAT","KPI_M_VALUE_FOR_MONEY", "KPI_M_WOULD_RECOMMEND" )
   and    rp.score >= 1 and rp.score <= 5
   group by rc.grouping, rt.rtype_name, sign(rp.score - 3);
   
   
   
   
   
   
   select "kpi_NP_scores" as data_set,
           rc.grouping,
           rt.rtype_name,
           case rp.score when 10 then 1 when 9 then 1 
                         when  8 then 0 when 7 then 0 
                         else -1 end as grp,
           sum(rc.clicks) as clicks
           
   from   t_rslt_count  rc,
          respattern    rp,
          rtype_pattern tp,
          rtype         rt
   where  rc.rfs_id     = v_RPT_ORG_RESULTS_rfs_id
   and    rc.typ        = "CNT"
   and    rc.rpatid     = rp.rpatid
   and    rp.rt_patid   = tp.rt_patid
   and    tp.q_rtypeid = rt.rtypeid 
   and    rt.rtype_name = "Q_NET_PROMOTER"
   and    rp.score >= 0 and rp.score <= 10
   group by rc.grouping, rt.rtype_name, 
            case rp.score when 10 then 1 when 9 then 1 when 8 then 0 when 7 then 0 else -1 end;
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_overwrite_existing`( IN  p_src_rpid       integer unsigned,
          IN  p_tgt_rpid       integer unsigned
         )
stored_procedure:
begin
   declare v_src_rpt_owner          integer unsigned;
   declare v_src_rfs_id             integer unsigned;
   declare v_tgt_rfs_id             integer unsigned;
   declare v_msg                    varchar(255);
   declare v_rows, v_err            int default 0;
   
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   
   
   select src.owner_uid into v_src_rpt_owner
   from report src,
        report tgt
   where src.rpt_type  = tgt.rpt_type
   and   src.orgid     = tgt.orgid
   and   src.owner_uid = tgt.owner_uid 
   and   src.rpid = p_src_rpid
   and   tgt.rpid = p_tgt_rpid;
   set v_rows = ROW_COUNT();
   
   if v_rows != 1 then
      set @sp_return_stat = 1, v_msg = concat( 'rpt_overwrite_existing: rpt mismatch ', p_src_rpid, " ", p_tgt_rpid);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;
   
   
   
   delete from report_entry where rpid = p_tgt_rpid;
   insert report_entry( rpid, renderid, order_seq, active, entry_type, display, 
                        format, counters, source_object, rtypeid, qid, pre_page_break_on )
      select p_tgt_rpid, renderid, order_seq, active, entry_type, display, 
                        format, counters, source_object, rtypeid, qid, pre_page_break_on
      from   report_entry
      where  rpid   = p_src_rpid;
 
   select rfs_id into  v_src_rfs_id
   from  rslt_filter_set 
   where rpid = p_src_rpid
   and   name = "RPT_SETUP";
   
   select rfs_id into  v_tgt_rfs_id
   from  rslt_filter_set 
   where rpid = p_tgt_rpid
   and   name = "RPT_SETUP";
   
   delete from rslt_filter_item where rfs_id = v_tgt_rfs_id;
   
   insert rslt_filter_item( rfs_id, active, item_type, qnid, rpatid, 
             val_name, val_type, val_I, val_T, val_S )
         select v_tgt_rfs_id, active, item_type, qnid, rpatid, 
                val_name, val_type, val_I, val_T, val_S 
         from   rslt_filter_item
         where  rfs_id = v_src_rfs_id
         and    active = 1;
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_report_wipeout`( IN p_rpid          integer unsigned
         )
stored_procedure:
begin
   declare v_msg                    varchar(255);
   declare v_rows, v_err            int default 0;
   
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   if not exists( select rpid from report where rpid = p_rpid ) then
      set @sp_return_stat = 1, v_msg = concat( 'rpt_report_wipeout: not found rpid ', p_rpid);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;
   
   
   
   
   
   delete DEL
   from   rslt_filter_set S,
          rslt_filter_item DEL
   where  S.rpid   = p_rpid
   and    S.rfs_id = DEL.rfs_id;
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "rslt_filter_item deleted rows = ", v_rows; end if;
   delete from rslt_filter_set
   where  rpid = p_rpid;
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "rslt_filter_set deleted rows = ", v_rows; end if;
   delete from report_recipient
   where  rpid = p_rpid;
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "report_recipient deleted rows = ", v_rows; end if;
   delete from report_entry
   where  rpid = p_rpid;
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "report_entry deleted rows = ", v_rows; end if;
 
   delete from cfg_user_rpt_access
   where  rpid = p_rpid;
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "cfg_user_rpt_access deleted rows = ", v_rows; end if;
    
   delete from report
   where  rpid = p_rpid;
   set v_rows = ROW_COUNT(); 
   if @sp_debug = 1 then select "report deleted rows = ", v_rows; end if;
 
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_run_org_S_type_F`( IN p_rpid      integer unsigned,
          IN p_uid       integer unsigned
         )
stored_procedure:
begin
   declare v_msg                   varchar(255);
   declare v_rows, v_err           int default 0;
   
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_setup_survey_filters`( 
          IN p_rpt_org_type char(1),
          IN p_src_rfs_id   integer unsigned, 
          IN p_tgt_rfs_id   integer unsigned
        )
stored_procedure:
begin
   declare v_num_rpatids int;
   declare v_num_qnids   int;
   declare v_msg         varchar(255);
   declare v_rows, v_err int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   /*
   item_type: meta_filter | rpatid (result pattern)
   val_type:
   I - Integer
   T - DateTime
   S - string
   val_name (meta_filter):
   
   filter_after_date  (date from)
   filter_before_date (date_to)
   one_orgid    (I = orgid)
   org_rank_N   (I Top = 5,10 Bot = -5, -10)  
   org_rank_kpi (I = rtypeid)
   date_group   (S = (M)onth, (Q)uarterly )
   */
   -- Clear past activity on tgt set
   delete from rslt_filter_item where rfs_id = p_tgt_rfs_id;
   
   -- copy all meta filters striaght across (qnid indepenant)
   insert rslt_filter_item
           ( rfs_id, active, item_type,
             val_name, val_type, val_I, val_T, val_S )
         select p_tgt_rfs_id, active, item_type,  
                val_name, val_type, val_I, val_T, val_S 
         from   rslt_filter_item
         where  rfs_id    = p_src_rfs_id
         and    active    = 1
         and    item_type = "meta_filter";
            
   -- src survey has it's local rpats that must get equivalent in each lower survey through report types
   -- the number of rpatids must be the same in each survey else rtype setup is incomplete and
   -- reporting will be be wrong
   case 
   when p_rpt_org_type = "S" then
      -- can use filter direct when single site
      insert rslt_filter_item( rfs_id, active, item_type, qnid, rpatid, val_type )
         select p_tgt_rfs_id, active, item_type,  qnid, rpatid, val_type
         from   rslt_filter_item
         where  rfs_id   = p_src_rfs_id
         and    active   = 1
         and    item_type = "rpatid";
         
   when ( p_rpt_org_type = "G" or p_rpt_org_type = "A" ) then
   
      select count(*) into v_num_rpatids
      from   rslt_filter_item
      where  rfs_id    = p_src_rfs_id
      and    active    = 1
      and    item_type = "rpatid";
      
      if v_num_rpatids = 0 then leave stored_procedure; end if;
      -- setup equivalent rpatids in lower surveys
      insert rslt_filter_item ( rfs_id, active, item_type, qnid, rpatid, val_type )
         select p_tgt_rfs_id, 1, "rpatid", rs.qnid, rs.rpatid, fi.val_type
         from   rslt_filter_item fi,
                respattern       rp,
                t_rpat_spec      rs
         where  fi.rfs_id    = p_src_rfs_id
         and    fi.active    = 1
         and    fi.item_type = "rpatid"
         and    fi.rpatid    = rp.rpatid
         and    rs.rfs_id    = p_tgt_rfs_id  -- review use ?
         and    rp.rt_patid  = rs.rt_patid;
       
      set v_rows = ROW_COUNT();
      
      select count(*) into v_num_qnids
      from   t_rpt_survey;
      
      if @sp_debug = 1 then
         select rs.qnid, v_num_rpatids as rpatids_req, count( fi.rpatid ) as rpatids_got
         from   t_rpt_survey     rs
            left outer join rslt_filter_item fi
               on  rs.qnid      = fi.qnid
               and fi.rfs_id    = p_tgt_rfs_id
               and fi.item_type = "rpatid"
         group by rs.qnid;
       end if;
         
      if (v_num_qnids * v_num_rpatids) != v_rows then
         set @sp_return_stat = 1, v_msg = concat( 'rpt_setup_survey_filters: rtype mapping incomplete rfs_id=', p_tgt_rfs_id);
         SIGNAL SQLSTATE '01000'
         SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
         leave stored_procedure; 
      end if;
   end case;
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_set_property_pick_list_filter`( 
          IN p_uid          integer unsigned,
          IN p_rpt_type     char(3),
          IN p_action       char(10), -- "(A)ll", "(S)ite", "(R)ank"
          IN p_one_orgid    integer unsigned,
          IN p_org_rank     integer,
          IN p_append       tinyint unsigned
         )
stored_procedure:
begin
   declare v_orgid             integer unsigned;
   declare v_rpid              integer unsigned;
   declare v_rpt_org_type      char(1);
   declare v_RPT_SETUP_rfs_id  integer unsigned;
   declare v_surveys_kpi_name  varchar(255);                            
   declare v_msg               varchar(255);
   declare v_rows, v_err       int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;   
   set @sp_return_stat = 0;
   
   select O.orgid, O.type into v_orgid, v_rpt_org_type
   from   users        U,
          organisation O
   where  U.orgid = O.orgid
   and    U.uid   = p_uid; 
   set v_rows = ROW_COUNT();
   if v_rows != 1 or v_rpt_org_type not in ("G", "A") then
      set @sp_return_stat = 1, v_msg = concat( 'rpt_set_property_pick_list_filter: invald uid/org type ', p_uid, " / ", v_rpt_org_type );
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if; 
   
   call rpt_ensure_scratchpad_report_setup( p_uid, p_rpt_type, null, v_rpid, v_RPT_SETUP_rfs_id);
   if @sp_debug = 1 then select  * from rslt_filter_item where rfs_id = v_RPT_SETUP_rfs_id and active = 1; end if;
   
   -- Unless in append mode for adding sites
   -- Clear existing group org selection which is equivalent to p_action = (A)ll
   if not  ( ifnull( p_append, 0 ) = 1 and p_action = "S" ) then
      update rslt_filter_item 
      set    active = 0
      where  rfs_id = v_RPT_SETUP_rfs_id 
      and   ( val_name = 'one_org' or  val_name like 'org_rank%' );
   end if;
   
   case p_action
   when "S" then  -- One site
      call rslt_filter_add_meta_filter
         ( v_RPT_SETUP_rfs_id, 'one_org', "I",
           p_one_orgid, -- IN p_val_I 
           null,   -- IN p_val_T
           null,
           p_append ); -- IN p_val_S
  
   when "R" then  -- Rank
      -- Need to identify what latest survey is scored by for  Q_NET_PROMOTER or KPI_M_OVERALL_SAT 
      -- "Q_KPI_MAIN" -> "KPI_M_OVERALL_SAT"   
      --                  Could also support "KPI_M_VALUE_FOR_MONEY", "KPI_M_WOULD_RECOMMEND" 
      select Q_RT.rtype_name into v_surveys_kpi_name
      from   survey_used    U,
             page           P,
             question       Q,
             question_rtype QR,
             rtype          Q_RT
      where  U.orgid    = v_orgid
      and    U.active   = 1
      and    U.date_end is null
      and    U.qnid     = P.qnid
      and    P.pid      = Q.pid
      and    Q.qid      = QR.qid
      and    QR.rtypeid = Q_RT.rtypeid
      and    Q_RT.rtype_name in ( "Q_NET_PROMOTER", "Q_KPI_MAIN" ) limit 1;
      if v_surveys_kpi_name = "Q_KPI_MAIN" then
         set v_surveys_kpi_name = "KPI_M_OVERALL_SAT";
      end if;
      if v_surveys_kpi_name is not null then
         call rslt_filter_add_meta_filter
         ( v_RPT_SETUP_rfs_id, "org_rank_kpi", "S",
           null, -- IN p_val_I 
           null, -- IN p_val_T
           "KPI_M_OVERALL_SAT", -- IN p_val_S
           0 );    -- p_append 
        
         call rslt_filter_add_meta_filter
         ( v_RPT_SETUP_rfs_id, "org_rank_N", "I",
           p_org_rank, -- IN p_val_I 
           null,   -- IN p_val_T
           null,   -- IN p_val_S 
           0 );    -- p_append 
      end if;
   when "A" then  -- All
      begin end; -- Already covered
   else
      set @sp_return_stat = 1, v_msg = concat( 'rpt_set_property_pick_list_filter: invalid p_action', p_action );
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure;
   end case;
   if @sp_debug = 1 then select * from rslt_filter_item where rfs_id = v_RPT_SETUP_rfs_id and active = 1; end if;
   
end$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_smry_collect_counts`( 
          IN p_top_org_type           char(1),
          IN p_rpt_top_qnid           integer unsigned,
          IN p_RPT_SETUP_rfs_id       integer unsigned,
          IN p_RPT_ORG_RESULTS_rfs_id integer unsigned
         )
stored_procedure:
begin
   declare v_msg                   varchar(255);
   declare v_rows, v_err           int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      drop temporary table if exists t_all_answer_patterns;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   call rpt_setup_survey_filters ( p_top_org_type, p_RPT_SETUP_rfs_id, p_RPT_ORG_RESULTS_rfs_id );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   
   call rslt_build_filtered_rid_list( p_rpt_top_qnid, p_RPT_ORG_RESULTS_rfs_id );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   call rslt_build_clicks( p_RPT_ORG_RESULTS_rfs_id, 0 );
   call rslt_build_mode_median_mean (
        p_RPT_ORG_RESULTS_rfs_id, 
        1, 
        0, 
        0  
      );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   
   insert t_rid_grp_counts( rfs_id, qnid, grouping, is_2dm, grp_key, rids )
      select p_RPT_ORG_RESULTS_rfs_id,
             rd.qnid,
             rd.grouping,
             0 as is_2dm, 
             rp.qid as grp_key,  
             count( distinct rt.rid ) as rids
      from
              t_rids      rd,
              result      rt,
              t_rpat_spec rp
      where   1 
      and     rd.rfs_id = p_RPT_ORG_RESULTS_rfs_id
      and     rp.rfs_id = p_RPT_ORG_RESULTS_rfs_id
      and     rd.rid    = rt.rid
      and     rt.rpatid = rp.rpatid
      and     rp.resgroup like "1DM%" 
      and     rp.collect_counts = 1
      group by rd.qnid, rd.grouping, rp.qid;
      
   
   insert t_rid_grp_counts( rfs_id, qnid, grouping, is_2dm, grp_key, rids )
      select p_RPT_ORG_RESULTS_rfs_id,
             rd.qnid,
             rd.grouping,
             1 as is_2dm, 
             rp.eid1 as grp_key,  
             count( distinct rt.rid ) as rids
      from
              t_rids      rd,
              result      rt,
              t_rpat_spec rp
      where   1 
      and     rd.rfs_id = p_RPT_ORG_RESULTS_rfs_id
      and     rp.rfs_id = p_RPT_ORG_RESULTS_rfs_id
      and     rd.rid    = rt.rid
      and     rt.rpatid = rp.rpatid
      and     rp.resgroup  = "2DM"      
      and     rp.collect_counts = 1
      group by rd.qnid, rd.grouping, rp.eid1;
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_smry_prepare_env`( IN p_rpid                    integer unsigned,
          IN p_uid                     integer unsigned,
          --
          OUT p_rpt_type               varchar(3),
          OUT p_top_org_type           char(1),
          OUT p_rpt_top_orgid          integer unsigned,
          OUT p_rpt_top_qnid           integer unsigned,
          --
          OUT p_survey_count           integer,
          OUT p_RPT_SETUP_rfs_id       integer unsigned,
          OUT p_RPT_ORG_RESULTS_rfs_id integer unsigned
        )
stored_procedure:
begin
   declare v_msg                   varchar(255);
   declare v_rows, v_err           int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      drop temporary table if exists t_all_answer_patterns;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   
   select R.rpt_type, R.orgid into p_rpt_type, p_rpt_top_orgid
   from   report       R
   where  R.rpid  = p_rpid;
   
   set v_rows = ROW_COUNT();
   if v_rows != 1 then
      set @sp_return_stat = 1, v_msg = concat( 'rpt_smry_prepare_env: unknown rpid ', p_rpid);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if; 
   call rpt_tables_setup ( "CREATE" );
   
   -- Copy owner main set to seperate from any user changes
   call rpt_establish_filter_set (
          p_rpid,                  -- IN p_rpid 
          p_uid,                   -- IN p_uid
          "RPT_SETUP",             -- IN p_filter_name 
          1,                       -- IN p_copy_rpt_owner, 
          p_RPT_SETUP_rfs_id       -- OUT p_user_rfs_id
          );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
      
   -- Main working filters to be derived
   call rpt_establish_filter_set (
          p_rpid,                  -- IN p_rpid 
          p_uid,                   -- IN p_uid
          "RPT_ORG_RESULTS",       -- IN p_filter_name 
          0,                       -- IN p_copy_rpt_owner,
          p_RPT_ORG_RESULTS_rfs_id -- OUT p_user_rfs_id
          );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
 
   call rpt_identify_orgs_and_surveys (
     p_rpid,                   -- IN  p_rpid    
     p_uid,                    -- IN  p_uid 
     p_RPT_SETUP_rfs_id,       -- IN  p_RPT_SETUP_rfs_id 
     p_RPT_ORG_RESULTS_rfs_id, -- IN  p_RPT_SETUP_FILTERS_rfs_id 
     p_survey_count,           -- OUT p_survey_count
     p_rpt_top_qnid,           -- OUT p_rpt_org_latest_qnid
     p_top_org_type            -- OUT p_rpt_org_type
     );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_smry_standard_output`( IN p_rfs_id        integer unsigned,
          IN p_org_type      char(1),
          IN p_survey_count  integer,
          IN p_rpt_top_qnid  integer unsigned,
          IN p_inc_detail    tinyint unsigned
         )
stored_procedure:
begin
   declare v_msg                   varchar(255);
   declare v_rows, v_err           int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
    
   if @sp_debug = 1 then
     select "rpt_smry_standard_output: debug data sets ..." as sp_dbg;
     select * from t_rpt_org;
     select * from t_rpt_survey;
     select * from rslt_filter_item where rfs_id = p_rfs_id order by qnid;
     select -- rc.rfs_id,
             rc.qnid,
             rc.grouping,
             rc.rpatid,
             rp.qid, rp.eid1, rp.eid2, rp.eid3, 
             rp.score,
             rc.typ,
             rc.clicks,
             cb.rids, -- count rids when not clear from clicks
             rc.av,
             q.title, z.title
     from          t_rslt_count rc
        inner join respattern   rp
           on  rc.rpatid  = rp.rpatid
           and rc.rfs_id  = p_rfs_id
        inner join questionnaire z
          on rc.qnid = z.qnid
        inner join question q
           on rp.qid = q.qid 
        left outer join t_rid_grp_counts cb
           on  cb.rfs_id   = p_rfs_id
           and rc.qnid     = cb.qnid
           and ifnull(rc.grouping,0) = ifnull(cb.grouping, 0)
           and rc.rpatid   = rp.rpatid            
           and   ( ( cb.is_2dm = 0 and rp.qid  = cb.grp_key ) or
                   ( cb.is_2dm = 1 and rp.eid1 = cb.grp_key ) )
     order by rc.qnid;
   end if;
   
   if p_survey_count = 1 and p_org_type = "S" then -- common simple case
         select rc.qnid,
                rc.grouping,
                rp.qid,
                rp.rt_patid,
                rp.score,
                rc.typ,
                rc.clicks,
                cb.rids, -- count rids when not clear from clicks
                rc.av
         from          t_rslt_count rc
            inner join respattern   rp
               on  rc.rpatid  = rp.rpatid
               and rc.rfs_id  = p_rfs_id
            left outer join t_rid_grp_counts cb
               on  cb.rfs_id   = p_rfs_id
               and rc.qnid     = cb.qnid
               and ifnull(rc.grouping,0) = ifnull(cb.grouping, 0)
               and rc.rpatid   = rp.rpatid            
               and   ( ( cb.is_2dm = 0 and rp.qid  = cb.grp_key ) or
                       ( cb.is_2dm = 1 and rp.eid1 = cb.grp_key ) ); 
   -- union all -- can't re-open temp table for 2nd time in single statement
         select qnid,
                grouping,
                null as qid,
                0 as rt_patid,
                -- 0 as qid, 0 as eid1, 0 as eid2, 0 as eid3, 
                null as score,
                typ, null as clicks, rids, null as av
         from   t_rslt_count 
         where typ not in ("CNT", "AMN")
         and   rfs_id = p_rfs_id;
   else   
      -- survey_count > 1 or group reporting - combine counts to latest survey directly linked to org
      select 
             p_rpt_top_qnid as qnid,
             rc.grouping,
             -- For groups should this be null, only sites needed the qid survey specific reporting?
             tgt_rp.qid, -- case p_org_type when "S" then tgt_rp.qid else null end as qid,
             src_rp.rt_patid,  -- all to generic rtype pattern.
             max(src_rp.score) as score, 
             rc.typ,
             sum(clicks) as clicks,
             sum(cb.rids) as rids,
             sum( rc.av * rc.clicks ) / sum(rc.clicks) as av
      from          t_rslt_count rc
         inner join respattern   src_rp
            on  rc.rfs_id = p_rfs_id
            and rc.rpatid = src_rp.rpatid
         inner join t_rpat_spec  tgt_rp  -- implicit from build of t_rslt_count, but need latest qid map
            on  src_rp.rt_patid = tgt_rp.rt_patid
            and tgt_rp.qnid     = p_rpt_top_qnid
            and tgt_rp.rfs_id   = p_rfs_id      
         left outer join t_rid_grp_counts cb
            on  cb.rfs_id   = p_rfs_id
            and rc.qnid     = cb.qnid
            and ifnull(rc.grouping,0) = ifnull(cb.grouping, 0)
            and rc.rpatid   = src_rp.rpatid            
            and   ( ( cb.is_2dm = 0 and src_rp.qid  = cb.grp_key ) or
                    ( cb.is_2dm = 1 and src_rp.eid1 = cb.grp_key ) )          
       group by rc.grouping, rc.typ, case p_org_type when "S" then tgt_rp.qid else null end, src_rp.rt_patid;
       select -- rfs_id,
             p_rpt_top_qnid,
             grouping,
             null as qid,
             0 as rt_patid,
             -- 0 as cid, 0 as eid1, 0 as eid2, 0 as eid3, 
             null as score,
             typ, 
             null as clicks, 
             sum(rids) as rids, 
             null as av
      from   t_rslt_count 
      where typ not in ("CNT", "AMN")
      and   rfs_id = p_rfs_id
      group by grouping, typ;
    end if;
    if p_inc_detail = 1 then 
       if p_survey_count = 1 and p_org_type = "S" then 
          select r.rid,
                 r.grouping,
                 case p_org_type when "S" then rp.qid else null end as qid,
                 rp.rt_patid,
                 rd.str,
                 rd.num,
                 rd.numf
          from  t_rids r,
                t_rslt_count rc,
                result_detail rd,
                respattern    rp
          where r.rfs_id  = p_rfs_id
          and   rc.rfs_id = p_rfs_id
          and   r.rid     = rd.rid
          and   rc.rpatid = rd.rpatid
          and   rd.rpatid = rp.rpatid;
       else
          -- although detail needs no further aggregation, mapping to latest survey qid is required
          select r.rid,
                 r.grouping,
                 tgt_rp.qid,
                 rp.rt_patid,
                 rd.str,
                 rd.num,
                 rd.numf
          from  t_rids r,
                -- t_rslt_count rc,
                result_detail rd,
                respattern    rp,
                t_rpat_spec   tgt_rp
          where r.rfs_id    = p_rfs_id
          and   r.rid       = rd.rid
          and   rd.rpatid   = rp.rpatid
          -- and  rc.rfs_id = p_rfs_id
          -- and  rc.rpatid = rd.rpatid
          and tgt_rp.rfs_id = p_rfs_id 
          and tgt_rp.qnid   = p_rpt_top_qnid
          and rp.rt_patid   = tgt_rp.rt_patid;
            
       end if;
    end if;
    
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_tables_setup`( IN p_action char(6)
         )
stored_procedure:
begin
   declare v_msg                   varchar(255);
   declare v_rows, v_err           int default 0;
   
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   case p_action
   when "DELETE" then
   drop temporary table if exists t_rpt_org;
   drop temporary table if exists t_rpt_survey;
   
   drop temporary table if exists t_rpat_spec;
   drop temporary table if exists t_rids;
   drop temporary table if exists t_rslt_count;
   drop temporary table if exists t_rid_grp_counts;
   
   when "CREATE" then
   CREATE TEMPORARY TABLE IF NOT EXISTS t_rpt_org( 
      orgid    integer unsigned not null,
      org_type char(1) not null,
      CONSTRAINT t_rpt_org_idx1 UNIQUE INDEX t_rpt_org_idx1 (orgid)
      ) ENGINE=MEMORY;
   CREATE TEMPORARY TABLE IF NOT EXISTS t_rpt_survey( 
      orgid       integer unsigned not null,
      org_type    char(1) not null,
      qnid        integer unsigned not null,
      date_start  datetime not null,
      date_end    datetime null,
      CONSTRAINT t_rpt_survey_idx1 UNIQUE INDEX t_rpt_survey_idx1 (qnid)
      ) ENGINE=MEMORY;
   CREATE TEMPORARY TABLE IF NOT EXISTS t_rpat_spec(
      rfs_id   integer unsigned not null,
      qnid     integer unsigned not null,
      resgroup char(4) null,
      collect_counts  tinyint unsigned not null, 
      rpatid   integer unsigned not null,
      txt_validation char(1) null,
      qid      integer unsigned not null, 
      eid1     integer unsigned not null, 
      eid2     integer unsigned not null, 
      eid3     integer unsigned not null,
      score    integer null,
      rt_patid integer unsigned null,
      INDEX t_rpat_spec_idx1 (rpatid)
      ) ENGINE=MEMORY;
   CREATE TEMPORARY TABLE IF NOT EXISTS t_rids( 
      rfs_id   integer unsigned not null,
      qnid     integer unsigned not null,
      grouping integer null,
      rid      integer unsigned not null,
      INDEX t_rids_idx1 (rid)
      ) ENGINE=MEMORY;
      
   CREATE TEMPORARY TABLE IF NOT EXISTS t_rslt_count(
      rfs_id   integer unsigned not null,
      qnid     integer unsigned not null,
      grouping integer null,
      typ      varchar(30)  not null, 
      rpatid   integer unsigned null,
      score    integer null,
      clicks   integer unsigned null, 
      rids     integer unsigned null, 
      av       numeric(38,10)   null,
      INDEX t_rslt_count_idx1 (rpatid)
      ) ENGINE=MEMORY;
   CREATE TEMPORARY TABLE IF NOT EXISTS t_rid_grp_counts(
      rfs_id   integer unsigned not null,
      qnid     integer unsigned not null,
      grouping integer null,
      is_2dm   tinyint unsigned not null,
      grp_key  integer unsigned not null, 
      rids     integer unsigned not null,
      INDEX t_rid_grp_counts_idx1 (grp_key)
      ) ENGINE=MEMORY;
   
   truncate table t_rpt_org;
   truncate table t_rpt_survey;
   truncate table t_rpat_spec;
   truncate table t_rids;
   truncate table t_rslt_count;
   truncate table t_rid_grp_counts;
   end case;
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_TEST`( IN p_rpid      integer unsigned,
          IN p_uid       integer unsigned
         )
stored_procedure:
begin
   declare v_rpt_type               varchar(3);
   declare v_top_org_type           char(1);
   declare v_rpt_top_orgid          integer unsigned; 
   declare v_rpt_top_qnid           integer unsigned;
   
   declare v_survey_count           integer;
   declare v_RPT_SETUP_rfs_id       integer unsigned;
   declare v_RPT_ORG_RESULTS_rfs_id integer unsigned;
          
   declare v_msg                    varchar(255);
   declare v_rows, v_err            int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   call rpt_smry_prepare_env 
        ( p_rpid, p_uid,
          
          v_rpt_type, v_top_org_type, v_rpt_top_orgid, v_rpt_top_qnid, v_survey_count, 
          v_RPT_SETUP_rfs_id, v_RPT_ORG_RESULTS_rfs_id 
        );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   
   
   insert t_rpat_spec( rfs_id, collect_counts,
                       qnid, resgroup, rpatid, txt_validation, qid, eid1, eid2, eid3, score, rt_patid)
      select v_RPT_ORG_RESULTS_rfs_id as rfs_id, 
             1 as collect_all_ans,
             r.qnid, r.resgroup, r.rpatid, r.txt_validation, r.qid, r.eid1, r.eid2, r.eid3, r.score, r.rt_patid                                 
      from   t_rpt_survey  s,
             rslt_rpat_spec_setup r
      where  s.qnid = r.qnid;
   
   call rpt_smry_collect_counts
        ( v_top_org_type, v_rpt_top_qnid, v_RPT_SETUP_rfs_id, v_RPT_ORG_RESULTS_rfs_id 
        );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   
   call rpt_smry_standard_output
        ( v_RPT_ORG_RESULTS_rfs_id,
          v_top_org_type,
          v_survey_count,
          v_rpt_top_qnid,
          1 
         );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rpt_TREND`( IN p_rpid      integer unsigned,
          IN p_uid       integer unsigned
         )
stored_procedure:
begin
   declare v_rpt_type               varchar(3);
   declare v_top_org_type           char(1);
   declare v_rpt_top_orgid          integer unsigned; 
   declare v_rpt_top_qnid           integer unsigned;
   --
   declare v_survey_count           integer;
   declare v_RPT_SETUP_rfs_id       integer unsigned;
   declare v_RPT_ORG_RESULTS_rfs_id integer unsigned;
   --
   declare v_pos_neg_clicks         integer unsigned;
   declare v_total_clicks           integer unsigned;
   declare v_msg                    varchar(255);
   declare v_rows, v_err            int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   call rpt_smry_prepare_env 
        ( p_rpid, p_uid,
          -- OUT
          v_rpt_type, v_top_org_type, v_rpt_top_orgid, v_rpt_top_qnid, v_survey_count, 
          v_RPT_SETUP_rfs_id, v_RPT_ORG_RESULTS_rfs_id 
        );
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   
   -- CUSTOM FILTER & COLLECTION NEEDS GO HERE 
   insert t_rpat_spec( rfs_id, collect_counts,
                       qnid, resgroup, rpatid, txt_validation, qid, eid1, eid2, eid3, score, rt_patid)         
      select v_RPT_ORG_RESULTS_rfs_id as rfs_id, 
             1 as collect_all_ans,
             r.qnid, r.resgroup, r.rpatid, r.txt_validation, r.qid, r.eid1, r.eid2, r.eid3, r.score, r.rt_patid 
      from   rslt_rpat_spec_setup r  
      where  r.qid in
       ( select distinct q.qid -- limit this to the KPI questions across the surveys
         from   t_rpt_survey   s,
                page           p,
                question       q,
                question_rtype qr,
                rtype q_rt
         where org_type   = "S"
         and   s.qnid     = p.qnid
         and   p.pid      = q.pid
         and   q.qid      = qr.qid
         and   qr.rtypeid = q_rt.rtypeid
         and (  (r.type = "NN" and  q_rt.rtype_name in ( "Q_KPI_MAIN", "Q_KPI_RECEPTION_AND_PROPERTY", "Q_KPI_ROOM" ) ) 
             or (r.type = "N"  and  q_rt.rtype_name = "Q_NET_PROMOTER")  -- new recomend
              )
        );
         
 --   ROOM_KPI
   -- Add in monthly/quarterly grouping to get trend ( front end should do this)
   
   if not exists ( select * from rslt_filter_item 
                   where rfs_id = v_RPT_SETUP_rfs_id and item_type = 'meta_filter' and val_name = "date_group" ) then
      insert rslt_filter_item (rfs_id, active, item_type,     qnid, rpatid, val_name, val_type, val_S) values
                  (v_RPT_SETUP_rfs_id,      1, 'meta_filter', null, null,   'date_group','S',"M");
   end if;
   call rpt_smry_collect_counts
        ( v_top_org_type, v_rpt_top_qnid, v_RPT_SETUP_rfs_id, v_RPT_ORG_RESULTS_rfs_id 
        );         
   if @sp_return_stat = 1 then leave stored_procedure; end if;
   -- Custom output
   -- Main KPI
   -- For overall, money, recommend KPI
   -- % score for each 
/*
   select sum(case rp.score when 3 then 0 else rc.clicks end ), sum(rc.clicks) 
   into   v_pos_neg_clicks, v_total_clicks
   from   t_rslt_count  rc,
          respattern    rp
   where  rc.rfs_id     = v_RPT_ORG_RESULTS_rfs_id
   and    rc.typ        = "CNT"
   and    rc.rpatid     = rp.rpatid
   and    rp.score >= 1 and rp.score <= 5;
   -- safeguard any divide by zero
  if v_pos_neg_clicks = 0 then set v_pos_neg_clicks = null; end if;
  if v_total_clicks = 0   then set v_total_clicks = null; end if;
*/
   select "kpi_scores" as data_set,
           rc.grouping,
           rt.rtype_name,
           sign(rp.score - 3) as grp,
           sum(rc.clicks) as clicks
   from   t_rslt_count  rc,
          respattern    rp,
          rtype_pattern tp,
          rtype         rt
   where  rc.rfs_id     = v_RPT_ORG_RESULTS_rfs_id
   and    rc.typ        = "CNT"
   and    rc.rpatid     = rp.rpatid
   and    rp.rt_patid   = tp.rt_patid
   and    tp.e1_rtypeid = rt.rtypeid -- for dim=1 rtype names
   and    rt.rtype_name in 
          -- 10/12/13 Now Trip A has expanded KPI, restrict returned data to overview needs
          ( "KPI_M_OVERALL_SAT","KPI_M_VALUE_FOR_MONEY", "KPI_M_WOULD_RECOMMEND" )
   and    rp.score >= 1 and rp.score <= 5
   group by rc.grouping, rt.rtype_name, sign(rp.score - 3);
   -- Net Promoter groups require diffrent scoring system
   -- 0 to 6 -ve
   -- 7,8    0
   -- 9, 10 +ve
   -- No need for seperate entry point, it is more a case of feeding alternative
   -- data & titles into existing chart
   select "kpi_NP_scores" as data_set,
           rc.grouping,
           rt.rtype_name,
           case rp.score when 10 then 1 when 9 then 1 
                         when  8 then 0 when 7 then 0 
                         else -1 end as grp,
           sum(rc.clicks) as clicks
   from   t_rslt_count  rc,
          respattern    rp,
          rtype_pattern tp,
          rtype         rt
   where  rc.rfs_id     = v_RPT_ORG_RESULTS_rfs_id
   and    rc.typ        = "CNT"
   and    rc.rpatid     = rp.rpatid
   and    rp.rt_patid   = tp.rt_patid
   and    tp.q_rtypeid = rt.rtypeid -- for q level
   and    rt.rtype_name = "Q_NET_PROMOTER"
   and    rp.score >= 0 and rp.score <= 10
   group by rc.grouping, rt.rtype_name, 
            case rp.score when 10 then 1 when 9 then 1 when 8 then 0 when 7 then 0 else -1 end;
   -- provide main counts: fltr_completed_rids, "smry_completed_rids" , "smry_no_reply_rids" 
   if v_survey_count = 1 then 
         select qnid,
                grouping,
                null as qid,
                0 as rt_patid,
                -- 0 as qid, 0 as eid1, 0 as eid2, 0 as eid3, 
                null as score,
                typ, null as clicks, rids, null as av
         from   t_rslt_count 
         where typ not in ("CNT", "AMN")
         and   rfs_id = v_RPT_ORG_RESULTS_rfs_id
         order by grouping;
   else
        select -- rfs_id,
             v_rpt_top_qnid,
             grouping,
             null as qid,
             0 as rt_patid,
             -- 0 as cid, 0 as eid1, 0 as eid2, 0 as eid3, 
             null as score,
             typ, 
             null as clicks, 
             sum(rids) as rids, 
             null as av
      from   t_rslt_count 
      where typ not in ("CNT", "AMN")
      and   rfs_id = v_RPT_ORG_RESULTS_rfs_id
      group by grouping, typ
      order by grouping;
   end if;
   
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rslt_build_clicks`( IN p_rfs_id                 integer unsigned,
          IN p_include_empty_results  tinyint 
         )
stored_procedure:
begin
   declare v_msg                   varchar(255);
   declare v_rows, v_err           int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      drop temporary table if exists t_all_answer_patterns;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
 
   insert t_rslt_count (rfs_id, qnid, typ, grouping, rpatid, clicks)
      select p_rfs_id,
             rd.qnid,
            "CNT" as typ,  
             rd.grouping,
             rt.rpatid,
             count(*) as clicks
      from  t_rids         rd,
            result         rt
          , t_rpat_spec    rs
      where rd.rfs_id = p_rfs_id
      and   rd.rid    = rt.rid
      and   rt.rpatid = rs.rpatid and rs.collect_counts = 1 and rs.rfs_id = p_rfs_id
      group by rd.qnid, rd.grouping, rt.rpatid;
   
   if p_include_empty_results = 1 then
      drop temporary table if exists t_all_answer_patterns;
      CREATE TEMPORARY TABLE t_all_answer_patterns( 
         qnid     integer unsigned not null,
         grouping integer null,
         rpatid   integer unsigned 
         ) ENGINE=MEMORY;
 
      insert t_all_answer_patterns ( qnid, grouping, rpatid )
      select z.qnid, 0, 
             r.rpatid
      from   t_rpt_survey z,
             page       p,
             question   q,
             respattern r
      where  p.qnid = z.qnid
      and    p.pid  = q.pid
      and    q.qid  = r.qid;
      
      delete aap
      from   t_all_answer_patterns aap,
             t_rslt_count rc
      where  aap.qnid     = rc.qnid
      and    aap.grouping = rc.grouping
      and    aap.rpatid   = rc.rpatid;
      
      
      insert t_rslt_count (rfs_id, qnid, typ, grouping, rpatid, clicks)
         select p_rfs_id, 
                qnid,
                "CNT" as typ,  
                grouping,
                rpatid,
                null as clicks
         from   t_all_answer_patterns;
         
      drop temporary table if exists t_all_answer_patterns;     
   end if;
   
   
   
   
   
   
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rslt_build_filtered_rid_list`( IN p_rpt_top_qnid integer unsigned,
          IN p_rfs_id       integer unsigned
         )
stored_procedure:
begin
/*
   declare v_rpatid_filter_matches_needed,
           v_all_filter_matches_needed, 
           v_qnid, v_uid           integer unsigned;
   declare v_filter_and_or         varchar(10) default "AND";
   declare v_mf_fully_completed,    
           v_mf_part_completed     tinyint;
*/
   declare v_mf_filter_before_date,
           v_mf_filter_after_date  datetime;
   declare v_date_grouping         char(3);
   declare v_rpatid_filter_matches_needed,
           v_all_filter_matches_needed 
                                   integer unsigned;
   declare v_filter_mode           varchar(10);
   declare v_email                 varchar(62);
   declare v_min_radio_fltr, 
           v_total_radio_fltr      int;
   declare v_msg                   varchar(255);
   declare v_rows, v_err           int default 0;
   
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   -- -------------------------------
   -- Pick up meta filters for date & grouping
   set v_mf_filter_before_date = fltr_meta_item_get_T( p_rfs_id, "filter_before_date"),
       v_mf_filter_after_date  = fltr_meta_item_get_T( p_rfs_id, "filter_after_date" ),
       v_date_grouping         = fltr_meta_item_get_S( p_rfs_id, "date_group" ),
       v_email                 = fltr_meta_item_get_S( p_rfs_id, "email" ),
       v_filter_mode           = ifnull( fltr_meta_item_get_S( p_rfs_id, "filter_mode" ), "AND" );
   if (v_date_grouping = "3M" or v_date_grouping = "6M") and v_mf_filter_before_date is null then
      -- this shouldn't happen, but safeguard from no end date when using 3/6M grouping
      set @month_end=LAST_DAY( now());
      set v_mf_filter_before_date=DATE_ADD( @month_end, INTERVAL '23:59:59.999999' HOUR_MICROSECOND);
   end if;
   -- -------------------------------
   -- Determine if filtering by standard 'rpaitd' result filters
   if v_filter_mode = "OR" then
      set v_rpatid_filter_matches_needed = 1;
   else
      -- DEFAULT "AND" MODE
      set v_rpatid_filter_matches_needed = 
      ( select count(*) 
        from  rslt_filter_item 
        where  rfs_id    = p_rfs_id
        and    qnid      = p_rpt_top_qnid
        and    item_type = "rpatid"
        and    active    = 1 );
      -- support "AND" across radio questions by adjusting count down since only 1 ans per q | sub q row
      select count( distinct q.qid, sign(eid2) * eid1 ), count(*) 
      into   v_min_radio_fltr, v_total_radio_fltr
      from   rslt_filter_item fi,
             respattern       rp,
             question         q,
             qtype            qt
      where  fi.rfs_id    = p_rfs_id
      and    fi.qnid      = p_rpt_top_qnid
      and    fi.item_type = "rpatid"
      and    fi.active    = 1
      and    fi.rpatid    = rp.rpatid
      and    rp.type in ("N", "NN")
      and    rp.qid       = q.qid        
      and    q.qtypeid    = qt.qtypeid
      and    qt.title in ( "radio_matrix", "radio" );
      set v_rpatid_filter_matches_needed = v_rpatid_filter_matches_needed - (v_total_radio_fltr - v_min_radio_fltr );
   end if;
   if @sp_debug = 1 then
      select "rslt_build_filtered_rid_list" as dbg_sp, p_rfs_id, v_mf_filter_before_date, v_mf_filter_after_date, v_date_grouping, v_filter_mode,
             v_min_radio_fltr, v_total_radio_fltr ,v_total_radio_fltr - v_min_radio_fltr as diff;
   end if;
   -- -------------------------------
   -- Tailored query to meet complexity of 'rpatid' filters requested
   -- initially just two simple cases which may expand over time with IM.
   -- -------------------------------
   -- (1) no external filter
   -- (2) just result detail filter, TBD - 'OR' logic inside questions
   
   if ( v_rpatid_filter_matches_needed = 0 ) then
      if v_email is null then
         insert t_rids( rfs_id, qnid, rid, grouping )
             select p_rfs_id, rd.qnid, rd.rid,
                    case v_date_grouping 
                    when "Q"  then 100 * year(last_update) + quarter(last_update)
                    when "M"  then EXTRACT(YEAR_MONTH FROM last_update)
                    when "3M" then EXTRACT(YEAR_MONTH FROM 
                                      DATE_SUB( v_mf_filter_before_date, INTERVAL 
                                                3*(period_diff( EXTRACT(YEAR_MONTH FROM v_mf_filter_before_date ), 
                                                                EXTRACT(YEAR_MONTH FROM last_update ) ) div 3)
                                                MONTH ) )
                    when "6M" then EXTRACT(YEAR_MONTH FROM 
                                      DATE_SUB( v_mf_filter_before_date, INTERVAL 
                                                6*(period_diff( EXTRACT(YEAR_MONTH FROM v_mf_filter_before_date ), 
                                                                EXTRACT(YEAR_MONTH FROM last_update ) ) div 6)
                                                MONTH ) )
                    else null end
            from   t_rpt_survey q,
                   rids         rd
            where  q.qnid     = rd.qnid
            and    rd.status  = 1 -- complete
            and  ( rd.last_update < v_mf_filter_before_date or v_mf_filter_before_date is null )
            and  ( rd.last_update > v_mf_filter_after_date  or v_mf_filter_after_date  is null );
      else
         set v_email = concat( "%", v_email, "%" );
         insert t_rids( rfs_id, qnid, rid, grouping )
             select p_rfs_id, rd.qnid, rd.rid,
                    case v_date_grouping 
                    when "Q"  then 100 * year(last_update) + quarter(last_update)
                    when "M"  then EXTRACT(YEAR_MONTH FROM last_update)
                    when "3M" then EXTRACT(YEAR_MONTH FROM 
                                      DATE_SUB( v_mf_filter_before_date, INTERVAL 
                                                3*(period_diff( EXTRACT(YEAR_MONTH FROM v_mf_filter_before_date ), 
                                                                EXTRACT(YEAR_MONTH FROM last_update ) ) div 3)
                                                MONTH ) )
                    when "6M" then EXTRACT(YEAR_MONTH FROM 
                                      DATE_SUB( v_mf_filter_before_date, INTERVAL 
                                                6*(period_diff( EXTRACT(YEAR_MONTH FROM v_mf_filter_before_date ), 
                                                                EXTRACT(YEAR_MONTH FROM last_update ) ) div 6)
                                                MONTH ) )
                    else null end
            from   t_rpt_survey q,
                   rids         rd
            where  q.qnid     = rd.qnid
            and    rd.status  = 1 -- complete
            and  ( rd.last_update < v_mf_filter_before_date or v_mf_filter_before_date is null )
            and  ( rd.last_update > v_mf_filter_after_date  or v_mf_filter_after_date  is null )
            and   rd.email like v_email;  -- case insensitive
      end if;
   else
      -- select v_rpatid_filter_matches_needed, p_rfs_id, v_date_grouping, v_mf_filter_before_date, v_mf_filter_after_date;
      -- Currently apply simple AND logic
      if v_email is null then
         insert t_rids( rfs_id,qnid, rid, grouping )
             select p_rfs_id, rd.qnid, rd.rid,
                    case v_date_grouping 
                    when "Q"  then 100 * year(last_update) + quarter(last_update)
                    when "M"  then EXTRACT(YEAR_MONTH FROM last_update)
                    when "3M" then EXTRACT(YEAR_MONTH FROM 
                                      DATE_SUB( v_mf_filter_before_date, INTERVAL 
                                                3*(period_diff( EXTRACT(YEAR_MONTH FROM v_mf_filter_before_date ), 
                                                                EXTRACT(YEAR_MONTH FROM last_update ) ) div 3)
                                                MONTH ) )
                    when "6M" then EXTRACT(YEAR_MONTH FROM 
                                      DATE_SUB( v_mf_filter_before_date, INTERVAL 
                                                6*(period_diff( EXTRACT(YEAR_MONTH FROM v_mf_filter_before_date ), 
                                                                EXTRACT(YEAR_MONTH FROM last_update ) ) div 6)
                                                MONTH ) )
                    else null end
            from   t_rpt_survey     q,
                   rids             rd,
                   rslt_filter_item rf,
                   result           rs
            where  q.qnid       = rd.qnid
            and    rd.status    = 1 -- complete
            and    rd.rid       = rs.rid
            and    rf.rfs_id    = p_rfs_id
            and    rf.rpatid    = rs.rpatid
            and  ( rd.last_update < v_mf_filter_before_date or v_mf_filter_before_date is null )
            and  ( rd.last_update > v_mf_filter_after_date  or v_mf_filter_after_date  is null )
            --
            and    rf.item_type = "rpatid"
            and    rf.active    = 1
            group by rd.qnid, rd.rid -- grouping impact TBD
            having count(*) >= v_rpatid_filter_matches_needed; -- apply AND (OR logic TBD)
      else
         set v_email = concat( "%", v_email, "%" );
         insert t_rids( rfs_id,qnid, rid, grouping )
             select p_rfs_id, rd.qnid, rd.rid,
                    case v_date_grouping 
                    when "Q"  then 100 * year(last_update) + quarter(last_update)
                    when "M"  then EXTRACT(YEAR_MONTH FROM last_update)
                    when "3M" then EXTRACT(YEAR_MONTH FROM 
                                      DATE_SUB( v_mf_filter_before_date, INTERVAL 
                                                3*(period_diff( EXTRACT(YEAR_MONTH FROM v_mf_filter_before_date ), 
                                                                EXTRACT(YEAR_MONTH FROM last_update ) ) div 3)
                                                MONTH ) )
                    when "6M" then EXTRACT(YEAR_MONTH FROM 
                                      DATE_SUB( v_mf_filter_before_date, INTERVAL 
                                                6*(period_diff( EXTRACT(YEAR_MONTH FROM v_mf_filter_before_date ), 
                                                                EXTRACT(YEAR_MONTH FROM last_update ) ) div 6)
                                                MONTH ) )
                    else null end
            from   t_rpt_survey     q,
                   rids             rd,
                   rslt_filter_item rf,
                   result           rs
            where  q.qnid       = rd.qnid
            and    rd.status    = 1 -- complete
            and    rd.rid       = rs.rid
            and    rf.rfs_id    = p_rfs_id
            and    rf.rpatid    = rs.rpatid
            and  ( rd.last_update < v_mf_filter_before_date or v_mf_filter_before_date is null )
            and  ( rd.last_update > v_mf_filter_after_date  or v_mf_filter_after_date  is null )
            and   rd.email like v_email   -- case insensitive
            --
            and    rf.item_type = "rpatid"
            and    rf.active    = 1
            group by rd.qnid, rd.rid -- grouping impact TBD
            having count(*) >= v_rpatid_filter_matches_needed; -- apply AND (OR logic TBD)
      end if;
   end if;
   -- Provide stats - empty result output is a bit basic
   insert t_rslt_count( rfs_id, qnid, typ, grouping, rids )
      select p_rfs_id, S.qnid, "fltr_completed_rids", R.grouping, count(R.rid)
      from  t_rpt_survey  S
         left outer join t_rids R
            on  S.qnid = R.qnid
            and R.rfs_id = p_rfs_id 
      group by  S.qnid, R.grouping;
   
   insert t_rslt_count( rfs_id, qnid, typ, grouping, rids )
      select p_rfs_id, S.qnid,
             case R.status when 1 then "smry_completed_rids" else "smry_no_reply_rids" end,
             case v_date_grouping 
             when "Q"  then 100 * year(last_update) + quarter(last_update)
             when "M"  then EXTRACT(YEAR_MONTH FROM last_update)
             when "3M" then EXTRACT(YEAR_MONTH FROM 
                               DATE_SUB( v_mf_filter_before_date, INTERVAL 
                                         3*(period_diff( EXTRACT(YEAR_MONTH FROM v_mf_filter_before_date ), 
                                                         EXTRACT(YEAR_MONTH FROM last_update ) ) div 3)
                                         MONTH ) )
             when "6M" then EXTRACT(YEAR_MONTH FROM 
                               DATE_SUB( v_mf_filter_before_date, INTERVAL 
                                         6*(period_diff( EXTRACT(YEAR_MONTH FROM v_mf_filter_before_date ), 
                                                         EXTRACT(YEAR_MONTH FROM last_update ) ) div 6)
                                         MONTH ) )
             else null end,
            count(R.rid)
      from  t_rpt_survey  S,
      -- left outer join 
           rids R
      --    on 
      where S.qnid = R.qnid
            and  ( R.last_update > v_mf_filter_before_date or v_mf_filter_before_date is null )
            and  ( R.last_update < v_mf_filter_after_date  or v_mf_filter_after_date  is null )
      group by S.qnid,
               case R.status when 1 then "smry_completed_rids" else "smry_no_reply_rids" end,
               case v_date_grouping 
               when "Q"  then 100 * year(last_update) + quarter(last_update)
               when "M"  then EXTRACT(YEAR_MONTH FROM last_update)
               when "3M" then EXTRACT(YEAR_MONTH FROM 
                                 DATE_SUB( v_mf_filter_before_date, INTERVAL 
                                           3*(period_diff( EXTRACT(YEAR_MONTH FROM v_mf_filter_before_date ), 
                                                           EXTRACT(YEAR_MONTH FROM last_update ) ) div 3)
                                           MONTH ) )
               when "6M" then EXTRACT(YEAR_MONTH FROM 
                                 DATE_SUB( v_mf_filter_before_date, INTERVAL 
                                           6*(period_diff( EXTRACT(YEAR_MONTH FROM v_mf_filter_before_date ), 
                                                            EXTRACT(YEAR_MONTH FROM last_update ) ) div 6)
                                           MONTH ) )
               else null end;
   
   -- set v_rows = ROW_COUNT();
   
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rslt_build_mode_median_mean`( IN p_rfs_id                integer unsigned,
          IN p_build_mean_counts     tinyint,
          IN p_build_mode_counts     tinyint, 
          IN p_build_median_counts   tinyint  
         )
stored_procedure:
begin
   declare v_msg                   varchar(255);
   declare v_rows, v_err           int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   if p_build_mean_counts = 1 then
      if exists( select * from t_rpat_spec where rfs_id = p_rfs_id and txt_validation in ( "I", "N" ) and collect_counts = 1 )
      then
         insert t_rslt_count( rfs_id, qnid, typ, grouping, rpatid, clicks, av)
            select p_rfs_id, rd.qnid,
                   "AMN" as typ,  
                   rd.grouping,
                   rt.rpatid,
                   count(*) as clicks,
                   avg( ifnull( rt.numf, cast( rt.num as decimal(38,10) ) ) ) as av
            from   t_rids         rd,
                   result_detail  rt
            where  rd.rfs_id = rfs_id
            and    rd.rid    = rt.rid
            and   (rt.num is not null or rt.numf is not null)
            group by rd.qnid, rd.grouping, rt.rpatid
            having   rt.rpatid in 
             ( select rpatid
               from   t_rpat_spec
               where  rfs_id = p_rfs_id
               and    txt_validation in ( "I", "N" )
               and    collect_counts = 1 
             );
      
      end if;
   end if;
   
   
 
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rslt_filter_add`( IN p_rpid  integer unsigned,
          IN p_suid  integer unsigned,
          
          IN p_qid   integer unsigned,
          IN p_eid1  integer unsigned,
          IN p_eid2  integer unsigned,
          IN p_eid3  integer unsigned,
          
          IN p_item_type   varchar(50), 
   		    IN p_val_name    varchar(150),
		      IN p_val_content varchar(255)
         )
stored_procedure:
begin
   declare v_qnid_from_suid,
           v_qnid_from_qid,
           v_qnid,   v_uid, 
           v_rpatid, v_rfi_id      integer unsigned;
   declare v_q_dim_actual,
           v_dim_check             tinyint;
   declare v_val_type              char(1);
   declare v_val_I                 int unsigned;
   declare v_val_T                 datetime;
   declare v_msg                   varchar(255);
   declare v_rows, v_err           int default 0;
   set @sp_return_stat = 0;
   select qnid into v_qnid_from_suid
   from   survey_used
   where  suid = p_suid;
   SET v_rows = ROW_COUNT();
   
   if v_rows != 1 then
      set @sp_return_stat = 1, v_msg = concat( 'rslt_filter_add: unknown suid ', p_suid);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if; 
   
   
   
   if p_item_type = "rpatid" and p_qid is not null and p_eid1 is not null then
 
      select dimension into v_q_dim_actual
      from question q, 
           qtype t
      where q.qtypeid = t.qtypeid
      and   q.qid = p_qid;
      
      
      if v_q_dim_actual != sign(p_eid1) + sign(ifnull(p_eid2,0)) + sign(ifnull(p_eid3,0))
      then
         set @sp_return_stat = 1, v_msg = concat("rslt_filter_add - question dimension mismatch, rpid ", p_rpid, " qid ", p_qid );
         SIGNAL SQLSTATE '01000'
         SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
         leave stored_procedure; 
      end if;
      
      select sum( dimension ) into v_dim_check 
      from   element
      where  qid    = p_qid
      and    eid  in ( p_eid1, p_eid2, p_eid3 );
      
      if not ( v_dim_check in (1,3,6) and
               v_dim_check = sign(p_eid1) + 2*sign(ifnull(p_eid2,0)) +  3*sign(ifnull(p_eid3,0)) )
      then
         set @sp_return_stat = 1, v_msg = concat("rslt_filter_add - element check not ok, rpid ", p_rpid);
         SIGNAL SQLSTATE '01000'
         SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
         leave stored_procedure; 
      end if;
      
      select  p.qnid into v_qnid_from_qid
      from    question q, page p
      where  q.qid = p_qid
      and    q.pid = p.pid;
      if ifnull(v_qnid_from_suid, -1) != ifnull(v_qnid_from_qid, -2) then
         set @sp_return_stat = 1, v_msg = concat("filter set qnid = ", v_qnid_from_suid,", but elements qnid = ", v_qnid_from_qid);
         SIGNAL SQLSTATE '01000'
         SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
         leave stored_procedure; 
      end if;
      
      
      call rslt_q_add ( null, 
                        p_qid, p_eid1, p_eid2, p_eid3,
                        null, 
                        null, 
                        null 
                      );
      select rpatid into v_rpatid
      from   respattern
      where  qid  = p_qid
      and    eid1 = p_eid1
      and    eid2 = ifnull( p_eid2, 0 )
      and    eid3 = ifnull( p_eid3, 0 );
      
      
      insert report_filter_item 
              ( rpid,   suid,  active, item_type, rpatid,   val_type )
         select p_rpid, p_suid, 1,     "rpatid",  v_rpatid, "N" from dual
         where  not exists ( select *
                             from   report_filter_item
                             where  rpid      = p_rpid
                             and    suid      = p_suid
                             and    item_type = "rpatid"
                             and    rpatid    = v_rpatid );
      
      set v_rows = ROW_COUNT();
   
      if v_rows = 1 then
         set v_rfi_id = LAST_INSERT_ID();
      else
         update report_filter_item
         set    active    = 1 
         where  rpid      = p_rpid
         and    suid      = p_suid
         and    item_type = "rpatid"
         and    rpatid    = v_rpatid
         and    active    = 0;
      end if;
   end if; 
 
   
   
   
   if p_item_type = "meta_filter" then
      case p_val_name 
   
   
      when "filter_after_date"  then set v_val_type = "T";
      when "filter_before_date" then set v_val_type = "T";
      else                           set v_val_type = "?";
      end case;
      set v_val_I = null, v_val_T = null;
      
      case v_val_type
      when "I" then
         set v_val_I = convert(p_val_content, UNSIGNED integer );
         
      when  "T" then
         set v_val_T = convert(p_val_content, datetime);
         
      when "?" then
         set @sp_return_stat = 1, v_msg = concat("meta_filter item ", p_val_name," for rpid=",p_rpid," not recognised" );
         SIGNAL SQLSTATE '01000'
         SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
         leave stored_procedure; 
      end case;
  
      
      update report_filter_item
      set    val_I  = v_val_I, 
             val_T  = v_val_T,
             active = 1
      where  rpid      = p_rpid
      and    suid      = p_suid
      and    item_type = p_item_type
      and    val_name  = p_val_name;
      
      set v_rows = ROW_COUNT();
 
      if v_rows = 0 then
         insert report_filter_item 
                 ( rpid,   suid,  active, item_type,    val_type, val_name,   val_I,   val_T )
            select p_rpid, p_suid, 1,     p_item_type, v_val_type, p_val_name, v_val_I, v_val_T from dual
            where  not exists ( select *
                                from   report_filter_item
                                where  rpid      = p_rpid
                                and    suid      = p_suid
                                and    item_type = p_item_type
                                and    val_name  = p_val_name );
         set v_rows = ROW_COUNT(), v_rfi_id = LAST_INSERT_ID(); 
      end if;
   end if;
   
   if @sp_debug = 1 then
         select *
         from   report_filter_item
         where  rpid      = p_rpid
         and    suid      = p_suid
         and    item_type = p_item_type;
   end if;
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rslt_filter_add_meta_filter`( 
          IN p_rfs_id     integer unsigned,
          IN p_val_name   varchar(150),
          IN p_val_type   char(1),
          IN p_val_I      int,
          IN p_val_T      datetime,
          IN p_val_S      varchar(255),
          IN p_append     tinyint unsigned
        )
stored_procedure:
begin                           
   declare v_msg               varchar(255);
   declare v_rows, v_err       int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;   
   set @sp_return_stat = 0;
   if p_rfs_id is null or p_val_name is null then
      set @sp_return_stat = 1, v_msg = concat( 'rslt_filter_add_meta_filter: p_rfs_id = ',p_rfs_id, " p_val_name = ", p_val_name );
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;
   
   -- Go for optomistic update assuming we are re-enabling existing filter with old value
   -- this heads of chance of overwiting multiple "one_org" when many entries
   update rslt_filter_item
   set    active = 1,
          val_I  = p_val_I,
          val_T  = p_val_T,
          val_S  = p_val_S
   where rfs_id    = p_rfs_id
   and   item_type = 'meta_filter'
   and   val_name  = p_val_name
   and   val_I    <=> p_val_I  -- null safe compare essential (e.g. multiple "one_org" ! )
   and   val_T    <=> p_val_T
   and   val_S    <=> p_val_S;
   set v_rows = ROW_COUNT();
      
   if v_rows = 0 and p_append = 0 then 
      -- no duplicate & not appending a duplicate meta filter so can we overwrite a single meta filter
      update rslt_filter_item
      set    active = 1,
             val_I  = p_val_I,
             val_T  = p_val_T,
             val_S  = p_val_S
      where rfs_id    = p_rfs_id
      and   item_type = 'meta_filter'
      and   val_name  = p_val_name;
      set v_rows = ROW_COUNT();
   end if;
   
   if v_rows = 0  then
      insert rslt_filter_item( rfs_id, active, item_type,   val_name,   val_type,   val_I,    val_T,   val_S)
         select p_rfs_id, 1, 'meta_filter', p_val_name, p_val_type, p_val_I, p_val_T, p_val_S
         from   dual
         where not exists(
            select rfs_id
            from   rslt_filter_item
            where  rfs_id    = p_rfs_id
            and    item_type = 'meta_filter'
            and    val_name  = p_val_name
            and    val_I    <=> p_val_I  -- null safe compare essential (e.g. multiple "one_org" ! )
            and    val_T    <=> p_val_T
            and    val_S    <=> p_val_S );
   end if;
end$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rslt_gen_survey_rpats`( IN p_qnid      integer unsigned
         )
stored_procedure:
begin
   declare v_rows, v_err  int default 0;
   
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      drop table if exists t_qid;
      drop table if exists t_respats;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   
   drop table if exists t_qid;
   drop table if exists t_respats;
   
   CREATE TEMPORARY TABLE t_qid
      ( qid  integer unsigned not null ) ENGINE=MEMORY;
   CREATE TEMPORARY TABLE t_respats
      ( qid        integer unsigned not null,
        type       varchar(3) not null,
        eid1       integer unsigned not null,
        eid2       integer unsigned not null,
        eid3       integer unsigned not null,
        n1         varchar(255),
        n2         varchar(255),
        n3         varchar(255) ) ENGINE=MEMORY;
   insert t_qid ( qid )
      select q.qid
      from  page      p,
            question  q,
            qtype     t
      where p.qnid    = p_qnid
      and   p.pid     = q.pid
      and   q.qtypeid = t.qtypeid
      and   t.title  != "pres_text"; 
      
   
   insert t_respats( qid, type, eid1, eid2, eid3 ) 
      select qid, "C1", 0, 0, 0
      from   t_qid;
   
   
   insert t_respats ( qid, type, eid1, eid2, eid3  )
      select Q.qid,
             concat( ifnull( E1.type,"" ), ifnull( E2.type,"" ), ifnull( E3.type,"" ) ) as rpat_type,
             E1.eid, 
             ifnull(E2.eid, 0), 
             ifnull(E3.eid, 0)
      from t_qid Q
           
           
           INNER JOIN element E1
              ON  Q.qid = E1.qid 
              AND E1.dimension = 1
           LEFT OUTER JOIN element E2
              ON  Q.qid = E2.qid 
              AND E2.dimension = 2
           LEFT OUTER JOIN element E3
              ON  Q.qid = E3.qid 
              AND E3.dimension = 3
      where 1;
   
   delete new
   from   t_respats  new,
          respattern old
   where  new.qid  = old.qid
   and    new.eid1 = old.eid1
   and    new.eid2 = old.eid2
   and    new.eid3 = old.eid3;
   insert respattern ( qid, type, eid1, eid2, eid3 )
      select qid, type, eid1, eid2, eid3 from t_respats;
      
   
   drop table if exists t_qid;
   drop table if exists t_respats;
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rslt_get_rid_answer`( IN p_rid        integer unsigned
         )
stored_procedure:
begin
   declare v_msg                   varchar(255);
   declare v_rows, v_err           int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
      -- Result Header
      select ifnull(Q_LT.lang_text_S, Q.title ) as q_title,
             R.last_update, R.name, R.email
      from   rids R
      inner join questionnaire Q
         on  R.rid  = p_rid
         and R.qnid = Q.qnid
      left outer join language_translation Q_LT
         on  Q.qnid      = Q_LT.obj_id
         and Q_LT.lotid  = (select lotid from language_object_type where item_type = "questionnaire.title" )
         and Q_LT.lngid  = R.lngid;
      select r.qnid,
             p_rid as rid,
             rp.qid,
             -- rt.rpatid, 
             rp.rt_patid,
             rp.type,
             rd.str,
             rd.num,
             rd.numf
      from             rids           r
            inner join result        rt
               on  r.rid  = p_rid
               and rt.rid = p_rid
            inner join respattern    rp
               on  rt.rpatid = rp.rpatid
               and rp.rt_patid  -- only item where report typing is complete
            left outer join result_detail rd
               on  rd.rpatid = rt.rpatid
               and rd.rid  = p_rid ;
 /* java not using sp . rt.rpatid,   rp.rt_patid, rp.type,   rd.str, rd.num, rd.numf, p_rid as rid, rp.qid */
/* other feature not used
   -- filled in 'other' element results will often give no result
   -- as rarely used
   --
      select h.rid,
             -- e.qid,
             h.eid1,
             h.str
      from   result_element_header h
             -- , element e
      where  h.rid = p_rid;
      -- and    h.eid1 = e.eid
*/
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rslt_q_add`( IN p_rid          integer unsigned,
          IN p_qid          integer unsigned,
          IN p_eid1         integer unsigned, 
          IN p_eid2         integer unsigned,
          IN p_eid3         integer unsigned,
          
          IN p_str          varchar(1000),
          IN p_num          integer,
          IN p_numf         numeric(38,10)
         )
stored_procedure:
begin
   declare v_rpatid integer unsigned;
   declare v_rpat_mode char(2);
   declare v_rpat_type varchar(3) default "";
   declare v_e1_type, v_e2_type, v_e3_type char(1);
   declare v_msg varchar(255);
   declare v_rows, v_err  int default 0;
   
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
  
   
   if     p_eid3 is not null then
      set v_rpat_mode = "D3";  
   elseif p_eid2 is not null then 
      set v_rpat_mode = "D2",
          p_eid3      = 0;
   elseif p_eid1 is not null then 
      set v_rpat_mode = "D1",
          p_eid2      = 0,
          p_eid3      = 0;
   else 
      set v_rpat_mode = "C1", 
          p_eid1      = 0,
          p_eid2      = 0,
          p_eid3      = 0;
   end if;
   if @sp_return_stat = 0 and not exists ( select qid from question where qid = p_qid ) then
      set @sp_return_stat = 1, v_msg = 'rslt_q_add: qid unknown ';
   end if;
   if @sp_return_stat = 0 and p_eid1 > 0 then
     if not exists ( select eid from element where eid = p_eid1 ) then
      set @sp_return_stat = 1, v_msg = 'rslt_q_add: p_eid1 unknown ';
     end if;
   end if;
   if @sp_return_stat = 0 and p_eid2 > 0 then
     if not exists ( select eid from element where eid = p_eid2 ) then
      set @sp_return_stat = 1, v_msg = 'rslt_q_add: p_eid2 unknown ';
     end if;
   end if;
  
   if @sp_return_stat = 0 and p_eid3 > 0 then
     if not exists ( select eid from element where eid = p_eid3 ) then
        set @sp_return_stat = 1, v_msg = 'rslt_q_add: p_eid3 unknown ';
      end if;
   end if;
   
   if @sp_return_stat = 1 then
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
        leave stored_procedure;
   end if;
   
   select rpatid, type into v_rpatid, v_rpat_type
   from  respattern
   where qid  = p_qid
   and   eid1 = p_eid1
   and   eid2 = p_eid2
   and   eid3 = p_eid3 limit 1;
   set v_rows = ROW_COUNT(); 
   
   if v_rows < 1 then 
      case v_rpat_mode
      when "D1" then
         select type into v_e1_type from element where eid = p_eid1;
         set    v_e2_type = "", v_e3_type = "";
      when "D2" then
         select type into v_e1_type from element where eid = p_eid1;
         select type into v_e2_type from element where eid = p_eid2;
         set    v_e3_type = "";
      when "D3" then
         select type into v_e1_type from element where eid = p_eid1;
         select type into v_e2_type from element where eid = p_eid2;
         select type into v_e3_type from element where eid = p_eid3;
      when "C1" then
         set v_rpat_type = "C1";
      end case;
  
      if not ( v_rpat_type = "C1" ) then 
         set v_rpat_type = concat( ifnull( v_e1_type,"" ), ifnull( v_e2_type,"" ), ifnull( v_e3_type,"" ) );
      end if;
      insert respattern ( qid,   type,   eid1,   eid2,   eid3)
         select p_qid, v_rpat_type, p_eid1, p_eid2, p_eid3 from dual
         where not exists( select * from  respattern
                           where qid  = p_qid
                           and   eid1 = p_eid1
                           and   eid2 = p_eid2
                           and   eid3 = p_eid3 );
   
      set v_rpatid = LAST_INSERT_ID(), v_rows = ROW_COUNT();
   end if;
   if @sp_debug = 1 then
      select v_rpatid;
   end if;
   if p_rid is null then 
       leave stored_procedure;
   end if; 
     
   if not exists ( select rid from rids where rid = p_rid ) then
      set @sp_return_stat = 1, v_msg = 'rslt_q_add: rid unknown ';
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;
   
   
   insert result( rid, rpatid )
      select p_rid, v_rpatid from dual
      where not exists ( select * from result
                         where rid  = p_rid
                         and rpatid = v_rpatid );
   set v_rows = ROW_COUNT();
   if v_rows = 1 and
      ( p_str  is not null or
        p_num  is not null or
        p_numf is not null   ) then
       insert result_detail( rid,   rpatid,   str,   num,   numf ) 
                    values ( p_rid, v_rpatid, p_str, p_num, p_numf);
   end if;
   
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rslt_set_rtypes_on_rpats`( IN p_qnid      integer unsigned
         )
stored_procedure:
begin
   declare v_msg          varchar(255);
   declare v_rows, v_err  int default 0;
      
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      drop table if exists t_qid;
      drop table if exists t_rt_pats;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   
   call rslt_gen_survey_rpats ( @qnid );
   if @sp_return_stat > 0 then
      set @sp_return_stat = 1, v_msg = concat( 'rslt_set_rtypes_on_rpats: respats failed qnid = ', p_qnid);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;
   
   
   
   
   drop table if exists t_qid;
   drop table if exists t_rt_pats;
   
   CREATE TEMPORARY TABLE t_qid(
   qid  integer unsigned not null ) ENGINE=MEMORY;
 
   CREATE TEMPORARY TABLE t_rt_pats( 
   incomplete  tinyint unsigned not null,
   rpatid      int unsigned not null,
   qid         int unsigned not null,
   eid1        int unsigned not null,
   eid2        int unsigned not null,
   eid3        int unsigned not null,
   q_rtypeid   int unsigned not null,
   e1_rtypeid  int unsigned not null,
   e2_rtypeid  int unsigned not null,
   e3_rtypeid  int unsigned not null,
   score       int,
   rt_patid    int unsigned null
   ) ENGINE=MEMORY;
   insert t_qid ( qid )
      select q.qid
      from  page      p,
            question  q
      where p.qnid    = p_qnid
      and   p.pid     = q.pid;
   
   insert t_rt_pats( incomplete, rpatid, 
                     qid,       eid1,       eid2,       eid3,
                     q_rtypeid, e1_rtypeid, e2_rtypeid, e3_rtypeid, score )
      select ( sign(RP.eid1) + sign(RP.eid2) + sign(RP.eid3) ) -
             ( ifnull(sign(E1.rtypeid),0) + ifnull(sign(E2.rtypeid),0) + ifnull(sign(E3.rtypeid), 0 ) ) as incomplete,
             RP.rpatid, RP.qid, RP.eid1, RP.eid2, RP.eid3, 
             QR.rtypeid, ifnull(E1.rtypeid,0) as e1_rtypeid, ifnull(E2.rtypeid,0) as e2_rtypeid, ifnull(E3.rtypeid,0) as e3_rtypeid,
             ifnull( R3.score, ifnull( R2.score, R1.score ) ) as score 
      from          t_qid          TQ
         INNER JOIN question_rtype QR
            ON TQ.qid = QR.qid          
         INNER JOIN respattern     RP
            ON TQ.qid = RP.qid 
         INNER JOIN element_rtype  E1
            ON RP.eid1 = E1.eid
         INNER JOIN rtype R1
            ON E1.rtypeid = R1.rtypeid
         
         LEFT OUTER JOIN element_rtype E2
            ON RP.eid2 = E2.eid
         LEFT OUTER JOIN rtype R2
            ON E2.rtypeid = R2.rtypeid 
         
         LEFT OUTER JOIN element_rtype E3
            ON RP.eid3 = E3.eid
         LEFT OUTER JOIN rtype R3
            ON E3.rtypeid = R3.rtypeid
       where 1;
   
   update t_rt_pats     new,
          rtype_pattern old
   set new.rt_patid = old.rt_patid
   where  new.q_rtypeid  = old.q_rtypeid
   and    new.e1_rtypeid = old.e1_rtypeid
   and    new.e2_rtypeid = old.e2_rtypeid
   and    new.e3_rtypeid = old.e3_rtypeid
   and    incomplete = 0; 
   SET v_rows = ROW_COUNT();
   if @sp_debug = 1 then
      select * from t_rt_pats order by incomplete desc, qid, eid1, eid2, eid3;
      select "to add" as to_add , B.*
      from   
             t_rt_pats B
      where  B.incomplete = 0
      and    B.rt_patid is null;
      
   end if;
    
   
   insert rtype_pattern( q_rtypeid, e1_rtypeid, e2_rtypeid, e3_rtypeid, score )
      select q_rtypeid, e1_rtypeid, e2_rtypeid, e3_rtypeid, score
      from   t_rt_pats
      where  incomplete = 0
      and    rt_patid is null;
   SET v_rows = ROW_COUNT();
   if v_rows > 0 then 
      if @sp_debug = 1 then select v_rows as new_rtype_pattern_added; end if;
   
      update t_rt_pats     new,
             rtype_pattern old
      set new.rt_patid = old.rt_patid
      where  new.q_rtypeid  = old.q_rtypeid
      and    new.e1_rtypeid = old.e1_rtypeid
      and    new.e2_rtypeid = old.e2_rtypeid
      and    new.e3_rtypeid = old.e3_rtypeid
      and    new.rt_patid is null; 
    end if;
   
   update respattern RP,
          t_qid Q
   set RP.rt_patid = null , RP.score = null
   where  RP.qid = Q.qid
   and    RP.rt_patid is not null;
   update respattern RP,  
          t_rt_pats  Q
   set RP.rt_patid = Q.rt_patid, RP.score = Q.score
   where  RP.rpatid = Q.rpatid
   and    Q.rt_patid is not null;
   SET v_rows = ROW_COUNT();
   if v_rows > 0 and @sp_debug = 1 then select v_rows as res_pats_setup_to_rtype_pats; end if;
      
   drop table if exists t_qid;
   drop table if exists t_rt_pats;
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `rslt_variable_add`( IN p_rid          integer unsigned,
          IN p_var_name     varchar(255),
          
          IN p_str          varchar(1000)
         )
stored_procedure:
begin
   declare v_svid integer unsigned;
   
   declare v_rows, v_err  int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   select svid into v_svid
   from   survey_variable
   where  name = p_var_name;
   set v_rows = ROW_COUNT(); 
   if v_rows < 1 then
      insert survey_variable( name )
         select p_var_name from dual
         where not exists( select * from  survey_variable
                           where name = p_var_name );
   
      set v_svid = LAST_INSERT_ID(), v_rows = ROW_COUNT();
   end if;
   insert result_variable_ans( rid, svid, str )
      select p_rid, v_svid, p_str from dual
      where not exists ( select * from result_variable_ans
                         where rid = p_rid
                         and svid  = v_svid );
   set v_rows = ROW_COUNT();
   
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `sys_cmd_table_read`( )
stored_procedure:
begin
   declare v_rows, v_err   int default 0;
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;   
   set @sp_return_stat = 0;
   select 
      cm.cmd_name, cm.cmd_method, cm.library, cm.cmd_callback, 
      r.name as role, ru.urid, r.active 
   from
       cfg_cmd cm, 
       rule_urole_cfg_cmd ru, 
       urole r 
   where 
       cm.cmd_id = ru.cmd_id 
   and ru.urid   = r.urid 
   and r.active  = 1
   order by r.name;
   
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `tracelog_add`( 
          IN  p_item   varchar(50),
          IN  p_msg    varchar(255),
          IN  p_num    int
         )
stored_procedure:
begin
   declare v_qtypeid integer unsigned;
      declare v_msg                    varchar(255);
   declare v_rows, v_err  int default 0;
   
   declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   INSERT trace_log( user_name, db_name,dt,item, msg, num)
      VALUES (CURRENT_USER(), DATABASE(), now(), p_item, p_msg, p_num );
      
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `usr_build`( INOUT p_uid           integer unsigned,
          IN  p_action          char(1), -- I = Insert, U = Update
          IN  p_orgid           integer unsigned,
          IN  p_lngid           tinyint unsigned,
          IN  p_active          tinyint unsigned,
          IN  p_contact_type    char(5),
          IN  p_username        varchar(40),
          IN  p_password        varchar(255),
          IN  p_first_name      varchar(100),
          IN  p_last_name       varchar(100),
          IN  p_position        varchar(255),
          IN  p_email           varchar(255),
          IN  p_tel             varchar(255),
          IN  p_fax             varchar(255),
          IN  p_mobile          varchar(255),
          IN  p_role_name       varchar(255)
         )
stored_procedure:
begin
   declare v_urid         int unsigned;
   declare v_msg          varchar(255);
   declare v_rows, v_err  int default 0;
      declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   -- Check role is valid
   if p_role_name is not null then
      select urid into v_urid
      from   urole 
      where  name = p_role_name;
      SET v_rows = ROW_COUNT();
      
      if v_rows != 1 then
         set @sp_return_stat = 1, v_msg = concat( 'usr_build: unknown role = ', p_role_name);
         SIGNAL SQLSTATE '01000'
         SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
         leave stored_procedure; 
      end if;
   end if;
   case
   when p_action = "I" then
      if p_lngid is null then 
         select lngid into p_lngid
         from   org_langs
         where  orgid = p_orgid
         and    use_as_default = 1;
      end if;
      insert users( uid,orgid,lngid,active,contact_type,
                    username,password,first_name,last_name,position,
                    email,tel,fax,mobile, created_at )
           values (p_uid,p_orgid,p_lngid,p_active,p_contact_type,
                    p_username,p_password,p_first_name,p_last_name,p_position,
                    p_email,p_tel,p_fax,mobile, now() );
      SET p_uid = LAST_INSERT_ID();
          
      insert user_urole( urid, uid ) values ( v_urid, p_uid );
      if @sp_debug = 1 then
         select p_uid as p_uid, v_urid as v_urid;
      end if;
 
   when p_action = "U" then
      update users
      set    orgid  = ifnull( p_orgid, orgid ),
             lngid  = ifnull( p_lngid, lngid ),
             active = ifnull( p_active, active ),
             contact_type   = ifnull( p_contact_type, contact_type ),
             username   = ifnull( p_username, username ),
             password   = ifnull( p_password, password ),
             first_name = ifnull( p_first_name, first_name ),
             last_name  = ifnull( p_last_name, last_name ),
             position   = ifnull( p_position,  position ),
             email  = ifnull( p_email, email ),
             tel    = ifnull( p_tel, tel ),
             fax    = ifnull( p_fax, fax ),
             mobile = ifnull( p_mobile, mobile )
      where  
             uid = p_uid;
     
      SET v_rows = ROW_COUNT();
      
      if v_rows != 1 then
         set @sp_return_stat = 1, v_msg = concat( 'usr_build: Users update failed for uid = ', p_uid);
         SIGNAL SQLSTATE '01000'
         SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
         leave stored_procedure; 
      end if;
     
      if v_urid is not null then
         -- insert user_urole ( urid, uid )
         --    select v_urid, p_uid from dual
         --    where not exists ( select * from user_urole
         --                       where uid  = p_uid
         --                       and urid = v_urid );
         
         -- Only 1 role initially
         update user_urole
         set    urid  = v_urid
         where  uid   = p_uid;
      end if;
      
   end case;
   
end stored_procedure$$

CREATE DEFINER=`testuser1`@`%` PROCEDURE `usr_read_profile`( IN p_uid           integer unsigned
         )
stored_procedure:
begin
   declare v_orgid        int unsigned;
   declare v_suid         int unsigned;
   declare v_qnid         int unsigned;
   declare v_pms_name     varchar(255);
   declare v_lngid        tinyint unsigned;
   declare v_language     varchar(255);
   declare v_qn_title     varchar(500);
   declare v_msg          varchar(255);
   declare v_rows, v_err  int default 0;
      declare EXIT handler for SQLEXCEPTION
   begin
      set @sp_return_stat = 1;
      RESIGNAL;
   end;
   set @sp_return_stat = 0;
   select orgid into v_orgid
   from   users
   where  uid = p_uid;
   set v_rows = ROW_COUNT();
   if v_rows != 1 then
      set @sp_return_stat = 1, v_msg = concat( 'usr_read_profile: unknown uid= ', p_uid);
      SIGNAL SQLSTATE '01000'
      SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 1000;
      leave stored_procedure; 
   end if;
   -- orgs pms
   select p_name into v_pms_name
   from   org_relation
   where  c_orgid = v_orgid
   and    p_type = "P"; -- PMS
   -- default language id & name
   select   L.lngid, L.name into v_lngid, v_language
   from     org_langs G,
            language  L
   where    G.orgid  = v_orgid
   and      G.lngid  = L.lngid
   and      G.use_as_default = 1 limit 1;
   -- latest used survey
   select suid, qnid into v_suid, v_qnid
   from survey_used 
   where orgid = v_orgid
   and   active = 1
   and   date_end is null limit 1;
   
   select title into v_qn_title
   from   questionnaire
   where  qnid = v_qnid;
   select 
       -- Establishment Details
       name,
       address1,
       address2,
       postcode,
       city,
       province,
       country,
       tel,
       fax,
       no_of_rooms,
       star_grading,
       v_pms_name as pms_provider,
       monthly_price,
       payment_method,
       payment_frequency,
       pricing_notes,
       
       -- System Information
       orgid, 
       remote_ref as pms_acc_no,
       ta_ref,
       v_qn_title survey_title,
       questionnaire_instructions,
       reporting_instructions,
       report_recipients,
       hot_alert_details,
      /* Not used
       type, active, system_status, send_invitation_delay_day, max_invitation_period_months, no_of_reminders,
       reminder_gap_days, notify_no_action_days,num_open_hot_alerts,date_last_pms_file, warn_no_upload_days, warn_no_invite_days, 
       */
       rid_notify  -- added 14/5/14
   from  organisation
   where orgid = v_orgid;
 
   select contact_type, uid, first_name, last_name, position, email, tel, fax, mobile, username
   from   users
   where  orgid  = v_orgid
   and    active = 1
   and    contact_type in ( "main", "acc", "mgr", "it" );
   -- default language links manual/preview
   -- main link -  full SG URL, but do we really want to show?
   -- user preview link -  local so will need prefixing by a system url
   -- e.g. http://feedback.intellimetrixx.com/Intellimetrixx/intelliuser/l/
   select source, link_type, link
   from   links 
   where  orgid = v_orgid
   and    suid  = v_suid
   and    lngid = v_lngid
   and    link_type in ( "man", "upv");
   -- Two result sets to support configuration of respone notifications
   select T.etid, T.lngid, T.name as_template_name, T.html_email, T.subject, T.body, T.envelope_sender_name, T.envelope_sender_email 
   from   email_template T
   where  T.orgid = v_orgid
   and    T.lngid = v_lngid
   and    T.name  = 'notify_rid_recieved';
   -- ResponseRecieved email list for org
   select onlid, orgid, type, email
   from   org_notify_list
   where  orgid = v_orgid
   and    type = "RR";
end stored_procedure$$

--
-- Functions
--
CREATE DEFINER=`testuser1`@`%` FUNCTION `fltr_meta_item_get_I`( p_rfs_id    integer unsigned,
          p_name      varchar(150)
         ) RETURNS int(11)
stored_function:
begin
   
   
   
   declare v_val_I integer;
   select val_I into v_val_I
            from  rslt_filter_item
            where rfs_id    = p_rfs_id
            and   active    = 1
            and   item_type = "meta_filter"
            and   val_type  = "I"
            and   val_name  = p_name limit 1;
   return v_val_I;
   
end stored_function$$

CREATE DEFINER=`testuser1`@`%` FUNCTION `fltr_meta_item_get_S`( p_rfs_id    integer unsigned,
          p_name      varchar(150)
         ) RETURNS varchar(255) CHARSET latin1
stored_function:
begin
   
   
   
   declare v_val_S varchar(255);
   
   select val_S into v_val_S
   from   rslt_filter_item
   where  rfs_id    = p_rfs_id
   and    active    = 1
   and    item_type = "meta_filter"
   and    val_type  = "S"
   and    val_name  = p_name limit 1;
   
   return v_val_S;
end stored_function$$

CREATE DEFINER=`testuser1`@`%` FUNCTION `fltr_meta_item_get_T`( p_rfs_id    integer unsigned,
          p_name      varchar(150)
         ) RETURNS datetime
stored_function:
begin
   declare v_val_T datetime;
   
   select val_T into v_val_T 
   from  rslt_filter_item
   where rfs_id    = p_rfs_id
   and   active    = 1
   and   item_type = "meta_filter"
   and   val_type  = "T"
   and   val_name  = p_name limit 1;
            
   return v_val_T;
   
end stored_function$$

CREATE DEFINER=`testuser1`@`%` FUNCTION `get_new_key`( p_old_key_name  varchar(30),
          p_new_key_name  varchar(30),
          p_old_key_id    integer unsigned
         ) RETURNS int(10) unsigned
stored_function:
begin
   
   
   
   
   return ( select mysql_id 
            from   ImportDB.key_migrate 
            where  syb_tab   = p_old_key_name
            and    mysql_tab = p_new_key_name
            and    syb_id    = p_old_key_id );
   
   
end stored_function$$

CREATE DEFINER=`testuser1`@`%` FUNCTION `rslt_check_rtype_answer_exists`( p_rid          integer unsigned,
          p_rtype_name1  varchar(255),
          p_rtype_name2  varchar(255),
          p_rtype_name3  varchar(255)
         ) RETURNS int(10) unsigned
stored_function:
begin
   
   declare v_rows, v_err           int default 0;
   
   declare v_ans_flag  integer unsigned;
   declare v_rt_patid  integer unsigned;
   select rt_patid into v_rt_patid
   from   rslt_rtype_pattern
   where  e1 = p_rtype_name1
   and    ifnull(e2, "") = ifnull(p_rtype_name2, "")
   and    ifnull(e3, "") = ifnull(p_rtype_name3, "");
   
   set v_ans_flag = 0, v_rows = ROW_COUNT();
   if v_rows = 1 then
      if exists ( select *
                  from   respattern p,
                         result r
                   where p.rt_patid = v_rt_patid
                   and   p.rpatid   = r.rpatid
                   and   r.rid      = p_rid ) then
          set v_ans_flag = 1;
      end if;
   end if;
   
   return v_ans_flag;
   
end stored_function$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `urole`
--

CREATE TABLE IF NOT EXISTS `urole` (
  `urid` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `active` tinyint(3) unsigned NOT NULL,
  PRIMARY KEY (`urid`),
  UNIQUE KEY `ugroup_idx0` (`name`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1 AUTO_INCREMENT=6 ;

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE IF NOT EXISTS `users` (
  `uid` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `orgid` int(10) unsigned NOT NULL,
  `lngid` tinyint(3) unsigned NOT NULL,
  `active` tinyint(3) unsigned NOT NULL,
  `contact_type` char(5) NOT NULL,
  `username` varchar(40) NOT NULL,
  `password` varchar(255) DEFAULT NULL,
  `first_name` varchar(100) DEFAULT '',
  `last_name` varchar(100) DEFAULT '',
  `position` varchar(255) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `tel` varchar(255) DEFAULT NULL,
  `fax` varchar(255) DEFAULT NULL,
  `mobile` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`uid`),
  UNIQUE KEY `users_idx3` (`email`),
  KEY `users_idx1` (`orgid`),
  KEY `FK_users__lng` (`lngid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1 AUTO_INCREMENT=50626 ;

-- --------------------------------------------------------

--
-- Table structure for table `user_session`
--

CREATE TABLE IF NOT EXISTS `user_session` (
  `uid` int(10) unsigned NOT NULL,
  `session_id` varchar(255) NOT NULL,
  `type` char(1) NOT NULL,
  `active` tinyint(3) unsigned NOT NULL,
  PRIMARY KEY (`uid`,`session_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `user_urole`
--

CREATE TABLE IF NOT EXISTS `user_urole` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `urid` int(10) unsigned NOT NULL,
  `uid` int(10) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_ugroup_idx0` (`uid`,`urid`),
  KEY `FK_uugrp__ugrp` (`urid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1 AUTO_INCREMENT=570 ;

-- --------------------------------------------------------

--
-- Stand-in structure for view `usr_role`
--
CREATE TABLE IF NOT EXISTS `usr_role` (
`role` varchar(255)
,`uid` int(10) unsigned
,`orgid` int(10) unsigned
,`lngid` tinyint(3) unsigned
,`active` tinyint(3) unsigned
,`contact_type` char(5)
,`username` varchar(40)
,`password` varchar(255)
,`first_name` varchar(100)
,`last_name` varchar(100)
,`position` varchar(255)
,`email` varchar(255)
,`tel` varchar(255)
,`fax` varchar(255)
,`mobile` varchar(255)
,`created_at` timestamp
,`updated_at` timestamp
);
-- --------------------------------------------------------

--
-- Structure for view `usr_role`
--
DROP TABLE IF EXISTS `usr_role`;

CREATE ALGORITHM=UNDEFINED DEFINER=`testuser1`@`%` SQL SECURITY DEFINER VIEW `usr_role` AS select `r`.`name` AS `role`,`u`.`uid` AS `uid`,`u`.`orgid` AS `orgid`,`u`.`lngid` AS `lngid`,`u`.`active` AS `active`,`u`.`contact_type` AS `contact_type`,`u`.`username` AS `username`,`u`.`password` AS `password`,`u`.`first_name` AS `first_name`,`u`.`last_name` AS `last_name`,`u`.`position` AS `position`,`u`.`email` AS `email`,`u`.`tel` AS `tel`,`u`.`fax` AS `fax`,`u`.`mobile` AS `mobile`,`u`.`created_at` AS `created_at`,`u`.`updated_at` AS `updated_at` from ((`users` `u` join `user_urole` `ur`) join `urole` `r`) where ((`u`.`uid` = `ur`.`uid`) and (`ur`.`urid` = `r`.`urid`));

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
