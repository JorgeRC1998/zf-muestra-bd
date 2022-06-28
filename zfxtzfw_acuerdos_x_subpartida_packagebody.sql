create or replace package body zfxtzfw_acuerdos_x_subpartida
is
-- Tipos/subtipos registro
    subtype rtytzfw_acuerdos_x_subpartida                is zfstzfw_acuerdos_x_subpartida.rtytzfw_acuerdos_x_subpartida;
-- Tipos tabla
     type prtyNew is record(
        vchTag  varchar2(30),
        vchData varchar2(128));
    type pttyNew is table of prtyNew
        index by binary_integer;
-- Variables
    ptblNew     pttyNew;
-- Constantes
   cvhNotNull   constant varchar2(2) := 'NN';
-- Excepciones
-- Procedimientos
-- Funciones
--------------------------------------------------- Create$FromXMLLst.prc ---------------------------------------------
procedure Create$FromXMLLst(
    iclbParam           in clob,
    oclbXML             out clob)
is
    xmlParam            xmltype;
    xmlTab              xmltype;
    xmlTab1             xmltype;
    nmbCont             number;
    vchAction           varchar2(15);
    clbRowSrc           clob;
    clbRowSet           clob;
    clbRowSetMsg        clob;
    clbMessage          clob;
    nmbMsgCode          number;
    vchMsgDesc          varchar2(256);
    blnRowsErr          boolean;
    blnRowErr           boolean;
    nmbNew              number;
--=====================================================================================================================
procedure InsertTable$(
    ivchTag             in varchar2,
    ivchValue           in varchar2)
is
begin
    nmbNew                  := nmbNew +1;
    ptblNew(nmbNew).vchTag  := ivchTag;
    ptblNew(nmbNew).vchData := '<' || ivchTag || '>' || ivchValue || '</' || ivchTag || '>';
end InsertTable$;
------------------------------------------------------------------------------------------------------------------------
procedure ConcatMsg$
is
begin
    clbRowSrc := zfx_library.ConcatTagValue(clbRowSrc,'ROW','MSGDESCRIPTION',vchMsgDesc);
    clbRowSrc := zfx_library.ConcatTagValue(clbRowSrc,'ROW','MSGCODE',nmbMsgCode);
end ConcatMsg$;
------------------------------------------------------------------------------------------------------------------------
function LookupErr$
return boolean
is
    xmlMessage xmltype;
begin
    nmbMsgCode := null;
    vchMsgDesc := null;
    if (clbMessage is not null) then
        xmlMessage := xmltype(clbMessage);
        nmbMsgCode := zfx_library.fnmbgetNumber4XML(xmlMessage,'CODE');
        vchMsgDesc := zfx_library.fvchgetString4XML(xmlMessage,'DESCRIPTION','N');
    end if;
    return(nmbMsgCode is not null and nmbMsgCode <> 7);
end LookupErr$;
--=====================================================================================================================
begin
    xmlParam := xmltype(iclbParam);
    xmlTab := xmlParam.extract('/ROWSET');
    nmbCont := 1;
    nmbNew := 0;
    blnRowsErr := false;
    While(xmlTab.existsnode('//ROW[' || nmbCont || ']') = 1)
    loop
        zfx_library.XmlOpen$(xmlTab,'//ROW[' || nmbCont || ']',xmlTab1);
        clbMessage := null;
        clbRowSrc := xmltab1.getClobVal;
        zfx_library.XmlValue$(xmlTab1,'/ROW/DBX_ACTION/text()',cvhNotNull,vchAction);
        case vchAction
             when 'CREATE' then clbRowSet := '<ROWSET>'||clbRowSrc||'</ROWSET>';
                    zfxtzfw_acuerdos_x_subpartida.Insert$(clbRowSet,clbMessage);
             when 'UPDATE' then clbRowSet := '<ROWSET>'||clbRowSrc||'</ROWSET>';
                    zfxtzfw_acuerdos_x_subpartida.Update$(clbRowSet,clbMessage);
             when 'DELETE' then clbRowSet := '<ROWSET>'||clbRowSrc||'</ROWSET>';
                    zfxtzfw_acuerdos_x_subpartida.Delete$(clbRowSet,clbMessage);
             else null;
        end case;
        blnRowErr := LookupErr$;
        blnRowsErr := blnRowErr or blnRowsErr;
        ConcatMsg$;
        clbRowsetMsg := clbRowsetMsg || clbRowSrc;
        nmbCont := nmbCont +1;
    End loop;
    if (not blnRowsErr) then
        commit;
        ptblNew.delete;
        clbRowsetMsg := '<ROWSET>' || clbRowsetMsg ||'</ROWSET>'||chr(10);
        oclbXML := replace(clbRowsetMsg, '<DBX_ACTION>CREATE</DBX_ACTION>',
                                         '<DBX_ACTION>NONE</DBX_ACTION>');
        return;
    end if;
    Rollback;
    clbRowsetMsg := '<ROWSET>' || clbRowsetMsg ||'</ROWSET>'||chr(10);
    oclbXML := clbRowsetMsg;
    return;
end Create$fromxmllst;
------------------------------------------------------ Insert$.prc ----------------------------------------------------
procedure Insert$(
    iclbRecord          in      clob,
    oclbXML             out     clob)
is
    rcrRecord          rtytzfw_acuerdos_x_subpartida;
    nmbErr             number;
    vchErrMsg          varchar2(256);
    xmlRecord          xmltype;
begin

    xmlRecord := xmltype(iclbRecord);

    rcrRecord.cdsubpartida                 := zfx_library.fvchgetString4XML(xmlRecord,  'CDSUBPARTIDA');
    rcrRecord.cdacuerdo                    := zfx_library.fvchgetString4XML(xmlRecord,  'CDACUERDO');
    rcrRecord.poarancel_acu                := zfx_library.fnmbgetNumber4XML(xmlRecord,  'POARANCEL_ACU');
    
    zfitzfw_acuerdos_x_subpartida.Insert$(nmbErr, vchErrMsg, rcrRecord);

    if (nmbErr is not null) then
        Rollback;
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
        return;
    end if;

    commit;
    vchErrMsg := 'Operacion se completo con exito.';
    oclbXML := zfx_library.fclbsetMessage2XML(7, vchErrMsg);
    return;
end Insert$;
------------------------------------------------------ Update$.prc ----------------------------------------------------
procedure Update$(
    iclbRecord          in      clob,
    oclbXML             out     clob)
is
    rcrRecord           rtytzfw_acuerdos_x_subpartida;
    nmbErr              number;
    vchErrMsg           varchar2(256);
    xmlRecord           xmltype;
begin

    xmlRecord := xmltype(iclbRecord);

    rcrRecord.cdsubpartida                := zfx_library.fvchgetString4XML(xmlRecord,  'CDSUBPARTIDA');
    rcrRecord.cdacuerdo                   := zfx_library.fvchgetString4XML(xmlRecord,  'CDACUERDO');
    rcrRecord.poarancel_acu               := zfx_library.fnmbgetNumber4XML(xmlRecord,  'POARANCEL_ACU');
    rcrRecord.id                          := zfx_library.fnmbgetNumber4XML(xmlRecord,  'ID');
    
    zfitzfw_acuerdos_x_subpartida.Update$(nmbErr, vchErrMsg, rcrRecord);

    if (nmbErr is not null) then
        Rollback;
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
        return;
    end if;

    commit;
    vchErrMsg := 'Operacion se completo con exito.';
    oclbXML := zfx_library.fclbsetMessage2XML(7, vchErrMsg);
    return;
end Update$;
------------------------------------------------------ Delete$.prc ----------------------------------------------------
procedure Delete$(
    iclbRecord          in      clob,
    oclbXML             out     clob)
is
    rcrRecord           rtytzfw_acuerdos_x_subpartida;
    nmbErr              number;
    vchErrMsg           varchar2(256);
    xmlRecord           xmltype;
begin

    xmlRecord := xmltype(iclbRecord);

    rcrRecord.id                          := zfx_library.fnmbgetNumber4XML(xmlRecord,  'ID');

    zfitzfw_acuerdos_x_subpartida.Delete$(nmbErr, vchErrMsg, rcrRecord);

    if (nmbErr is not null) then
        Rollback;
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
        return;
    end if;

    commit;
    vchErrMsg := 'Operacion se completo con exito.';
    oclbXML := zfx_library.fclbsetMessage2XML(7, vchErrMsg);
    return;
end Delete$;
--------------------------------------- XQuery$.prc -------------------------------------------------------------------
procedure XQuery(
    iclbParam           in clob,
    oclbXML             out clob)
is
    nmbErr              number;
    vchErrMsg           varchar2(256);
    vchFilter           varchar2(1024);
    clbXMLResult        clob;
    xmlRecord           xmltype;
begin
    xmlRecord := xmltype(iclbParam);

    vchFilter           := zfx_library.fvchgetString4XML(xmlRecord,  'FILTER');

    zfitzfw_acuerdos_x_subpartida.XQuery(nmbErr, vchErrMsg, vchFilter, clbXMLResult);

    if (nmbErr is not null) then
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr,vchErrMsg);
        return;
    end if;
    if (clbXMLResult is not null) then
        oclbXML := clbXMLResult;
    else
        vchErrMsg := 'No se encontraron registros';
        oclbXML := zfx_library.fclbsetMessage2XML(6,vchErrMsg);
    end if;
    return;
end XQuery;
--=====================================================================================================================
begin
    null;
end zfxtzfw_acuerdos_x_subpartida;