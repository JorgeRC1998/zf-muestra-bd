package body zfxtzfw_actas_transitos
is
-- Tipos/subtipos registro
    subtype rtytzfw_actas_transitos                is zfstzfw_actas_transitos.rtytzfw_actas_transitos;
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
                    zfxtzfw_actas_transitos.Insert$(clbRowSet,clbMessage);
             when 'UPDATE' then clbRowSet := '<ROWSET>'||clbRowSrc||'</ROWSET>';
                    zfxtzfw_actas_transitos.Update$(clbRowSet,clbMessage);
             when 'DELETE' then clbRowSet := '<ROWSET>'||clbRowSrc||'</ROWSET>';
                    zfxtzfw_actas_transitos.Delete$(clbRowSet,clbMessage);
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
    rcrRecord          rtytzfw_actas_transitos;
    nmbErr             number;
    vchErrMsg          varchar2(256);
    xmlRecord          xmltype;
begin

    xmlRecord := xmltype(iclbRecord);

    rcrRecord.nmtransito            := zfx_library.fvchgetString4XML(xmlRecord,  'NMTRANSITO');
    rcrRecord.cdcia_usuaria         := zfx_library.fvchgetString4XML(xmlRecord,  'CDCIA_USUARIA');
    rcrRecord.nmacta                := zfx_library.fnmbgetNumber4XML(xmlRecord,  'NMACTA');
    rcrRecord.cdaduana              := zfx_library.fvchgetString4XML(xmlRecord,  'CDADUANA');
    rcrRecord.fedesde               := zfx_library.fdtegetDate4XML(xmlRecord,  'FEDESDE');
    rcrRecord.fehasta               := zfx_library.fdtegetDate4XML(xmlRecord,  'FEHASTA');
    rcrRecord.snincon_bultos        := zfx_library.fvchgetString4XML(xmlRecord,  'SNINCON_BULTOS');
    rcrRecord.snincon_peso          := zfx_library.fvchgetString4XML(xmlRecord,  'SNINCON_PESO');
    rcrRecord.snincon_estmcia       := zfx_library.fvchgetString4XML(xmlRecord,  'SNINCON_ESTMCIA');
    rcrRecord.sndescrip_mcia        := zfx_library.fvchgetString4XML(xmlRecord,  'SNDESCRIP_MCIA');
    rcrRecord.snincon_termvenc      := zfx_library.fvchgetString4XML(xmlRecord,  'SNINCON_TERMVENC');
	rcrRecord.dsincon_otro          := zfx_library.fvchgetString4XML(xmlRecord,  'DSINCON_OTRO');
    rcrRecord.dsobservacion         := zfx_library.fvchgetString4XML(xmlRecord,  'DSOBSERVACION');
    rcrRecord.cdusuario_cierre      := zfx_library.fvchgetString4XML(xmlRecord,  'CDUSUARIO_CIERRE');
    rcrRecord.fecierre              := zfx_library.fdtegetDate4XML(xmlRecord,  'FECIERRE');

    zfitzfw_actas_transitos.Insert$(nmbErr, vchErrMsg, rcrRecord);

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
    rcrRecord           rtytzfw_actas_transitos;
    nmbErr              number;
    vchErrMsg           varchar2(256);
    xmlRecord           xmltype;
begin

    xmlRecord := xmltype(iclbRecord);

    rcrRecord.nmtransito            := zfx_library.fvchgetString4XML(xmlRecord,  'NMTRANSITO');
    rcrRecord.cdcia_usuaria         := zfx_library.fvchgetString4XML(xmlRecord,  'CDCIA_USUARIA');
    rcrRecord.nmacta                := zfx_library.fnmbgetNumber4XML(xmlRecord,  'NMACTA');
    rcrRecord.cdaduana              := zfx_library.fvchgetString4XML(xmlRecord,  'CDADUANA');
    rcrRecord.fedesde               := zfx_library.fdtegetDate4XML(xmlRecord,  'FEDESDE');
    rcrRecord.fehasta               := zfx_library.fdtegetDate4XML(xmlRecord,  'FEHASTA');
    rcrRecord.snincon_bultos        := zfx_library.fvchgetString4XML(xmlRecord,  'SNINCON_BULTOS');
    rcrRecord.snincon_peso          := zfx_library.fvchgetString4XML(xmlRecord,  'SNINCON_PESO');
    rcrRecord.snincon_estmcia       := zfx_library.fvchgetString4XML(xmlRecord,  'SNINCON_ESTMCIA');
    rcrRecord.sndescrip_mcia        := zfx_library.fvchgetString4XML(xmlRecord,  'SNDESCRIP_MCIA');
    rcrRecord.snincon_termvenc      := zfx_library.fvchgetString4XML(xmlRecord,  'SNINCON_TERMVENC');
	rcrRecord.dsincon_otro          := zfx_library.fvchgetString4XML(xmlRecord,  'DSINCON_OTRO');
    rcrRecord.dsobservacion         := zfx_library.fvchgetString4XML(xmlRecord,  'DSOBSERVACION');
    rcrRecord.cdusuario_cierre      := zfx_library.fvchgetString4XML(xmlRecord,  'CDUSUARIO_CIERRE');
    rcrRecord.fecierre              := zfx_library.fdtegetDate4XML(xmlRecord,  'FECIERRE');
    rcrRecord.id                    := zfx_library.fnmbgetNumber4XML(xmlRecord,  'ID');

    zfitzfw_actas_transitos.Update$(nmbErr, vchErrMsg, rcrRecord);

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
    rcrRecord           rtytzfw_actas_transitos;
    nmbErr              number;
    vchErrMsg           varchar2(256);
    xmlRecord           xmltype;
begin

    xmlRecord := xmltype(iclbRecord);

    rcrRecord.id                       := zfx_library.fnmbgetNumber4XML(xmlRecord,  'ID');

    zfitzfw_actas_transitos.Delete$(nmbErr, vchErrMsg, rcrRecord);

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

    zfitzfw_actas_transitos.XQuery(nmbErr, vchErrMsg,vchFilter,clbXMLResult);

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
--------------------------------------- XActaTransito.prc -------------------------------------------------------------------
procedure XActaTransito(
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

    zfitzfw_actas_transitos.XActaTransito(nmbErr, vchErrMsg,vchFilter,clbXMLResult);

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
end XActaTransito;
--------------------------------------- XActaTrnstoCrre.prc -------------------------------------------------------------------
procedure XActaTrnstoCrre(
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

    zfitzfw_actas_transitos.XActaTrnstoCrre(nmbErr, vchErrMsg,vchFilter,clbXMLResult);

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
end XActaTrnstoCrre;
--=====================================================================================================================
begin
    null;
end zfxtzfw_actas_transitos;