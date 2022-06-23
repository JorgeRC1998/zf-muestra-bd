create or replace PACKAGE BODY         "ZFXTZFW_ESTADOS_PLANILLA"
is
/****************************************************************************************

    NOMBRE:       zfxtzfw_estados_planilla
    PROPOSITO:    Manejar todas las operaciones de la tabla de estados planilla
                  Estado Corte.
    REVISION:
    Ver        Fecha       Autor              Descripcion
    ---------  ----------  ---------------    ------------------------------------
    1.0        20190205                       Creacion del paquete
    2.0        20190205    Guillermo Prieto   Modificacion del paquete para incluir la validacion
                                              En la pantalla de usuario calificado desprecinte
                                              se debe validar que si el usuario ya envio por primera
                                              vez la placa que tiene asociado el transito, si no lo
                                              envio por primera vez no debe permitir realizar el desprecinte
                                              y debe mostrar mensaje: "La compania (nombre de la compania)
                                              debe enviar la placa para desprecintar". Esta validacion se hace
                                              por cada placa de
                                              acuerdo a lo solicitado en el req 5 del documento
                                              F02-PS030223 Especificaci¿n de Requisitos Mejoras 2147 (Planillas).doc.
                                              Se modifica el paquete para incluir el procedimiento ValSiRealizoEnvio
                                              para adicionar la validacion respectiva
    3.0        20190212    Guillermo Prieto   Modificacion del paquete para incluir la validacion
                                              En la pantalla de usuario calificado registro
                                              Req 2 Editar y Enviar varias veces una placa
                                              se debe validar que si el usuario ya paso a PENDIENTE el
                                              documento por primera vez de
                                              acuerdo a lo solicitado en el req 2 del documento
                                              F02-PS030223 Especificaci¿n de Requisitos Mejoras 2147 (Planillas).doc.
                                              Se modifica el paquete para incluir el procedimiento ValPendientePriVez
                                              para adicionar la validacion respectiva
                                              Se modifica el paquete para incluir el procedimiento ValTransitoPriVez
                                              para adicionar la validacion respectiva
                                              Se modifica el paquete para incluir el procedimiento PasPendienteMasiv
                                              para adicionar la validacion respectiva
*****************************************************************************************/
-- Tipos/subtipos registro
    subtype rtytzfw_estados_planilla                is zfstzfw_estados_planilla.rtytzfw_estados_planilla;
    subtype pttyXML                                 is zfx_library.gttyXML;
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
                    zfxtzfw_estados_planilla.Insert$(clbRowSet,clbMessage);
             when 'UPDATE' then clbRowSet := '<ROWSET>'||clbRowSrc||'</ROWSET>';
                   zfxtzfw_estados_planilla.Update$(clbRowSet,clbMessage);
             when 'DELETE' then clbRowSet := '<ROWSET>'||clbRowSrc||'</ROWSET>';
                    zfxtzfw_estados_planilla.Delete$(clbRowSet,clbMessage);
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
procedure Enviar$Monitoreo(
    iclbRecord          in      clob,
    oclbXML             out     clob)
is
    rcrRecord          rtytzfw_estados_planilla;
    nmbErr             number;
    vchErrMsg          varchar2(256);
    vchTipo            varchar2(500);
    xmlRecord          xmltype;
    tblXML              pttyXML;
    vchCorreo           TZFW_USUARIO_CORREO.correo%type;
    vchCia              TZFW_USUARIO_CORREO.cdcia_usuaria%type;
    vchTipoDespre       varchar2(1);
begin

    xmlRecord := xmltype(iclbRecord);

    rcrRecord.cdplaca                    := zfx_library.fvchgetString4XML(xmlRecord,'CDPLACA');
    rcrRecord.cdcia_usuaria              := zfx_library.fvchgetString4XML(xmlRecord,'CDCIA_USUARIA');
    rcrRecord.feingreso                  := zfx_library.fdtegetDate4XML(xmlRecord,'FEINGRESO');
    rcrRecord.cdusuario                  := zfx_library.fvchgetString4XML(xmlRecord,'CDUSUARIO');    
    vchCia                               := zfx_library.fvchgetString4XML(xmlRecord,'CDCOMPANIA');

    zfstzfw_estados_planilla.Enviar$Monitoreo(rcrRecord, nmbErr, vchErrMsg);

    if (nmbErr is not null) then
        Rollback;
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
        return;
    end if;
--Rollback;
    commit;
  dbms_output.put_line(vchCia);  
    zfstzfw_transitos_documentos.EnvioTipoDesprecinte(rcrRecord.cdplaca,rcrRecord.cdcia_usuaria,rcrRecord.feingreso,rcrRecord.cdusuario,vchCia,nmbErr,vchErrMsg,vchTipo,vchCorreo,vchTipoDespre);
    if (vchErrMsg is not null) then
        tblXML(1).vchTag := 'CODE';
        tblXML(1).vchValue := '';
        tblXML(2).vchTag := 'DESCRIPTION';
        tblXML(2).vchValue := vchErrMsg;
        tblXML(3).vchTag := 'SOLICITUD';
        tblXML(3).vchValue := vchTipo;
        tblXML(4).vchTag := 'CORREO';
        tblXML(4).vchValue := vchCorreo;
        tblXML(5).vchTag := 'CDTIPO';
        tblXML(5).vchValue := vchTipoDespre;
        oclbXML := zfx_library.fclbGetXML4Table(tblXML);
        return;
    end if;
    
    vchErrMsg := 'Operacion se completo con exito.';
    oclbXML := zfx_library.fclbsetMessage2XML(7, vchErrMsg);
    return;
end Enviar$Monitoreo;
------------------------------------------------------ Insert$.prc ----------------------------------------------------
procedure Validar$Envio(
    iclbRecord          in      clob,
    oclbXML             out     clob)
is
    rcrRecord          rtytzfw_estados_planilla;
    nmbErr             number;
    vchErrMsg          varchar2(256);
    xmlRecord          xmltype;
begin

    xmlRecord := xmltype(iclbRecord);

    rcrRecord.cdplaca                    := zfx_library.fvchgetString4XML(xmlRecord,'CDPLACA');
    rcrRecord.cdcia_usuaria              := zfx_library.fvchgetString4XML(xmlRecord,'CDCIA_USUARIA');
    rcrRecord.feingreso                  := zfx_library.fdtegetDate4XML(xmlRecord,'FEINGRESO');
    rcrRecord.cdusuario                  := zfx_library.fvchgetString4XML(xmlRecord,'CDUSUARIO');

    zfstzfw_estados_planilla.Validar$Envio(rcrRecord, nmbErr, vchErrMsg);

    if (nmbErr is not null) then
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
        return;
    end if;

    vchErrMsg := 'Operacion se completo con exito.';
    oclbXML := zfx_library.fclbsetMessage2XML(7, vchErrMsg);
    return;
end Validar$Envio;
------------------------------------------------------ Insert$.prc ----------------------------------------------------
procedure Insert$(
    iclbRecord          in      clob,
    oclbXML             out     clob)
is
    rcrRecord          rtytzfw_estados_planilla;
    nmbErr             number;
    vchErrMsg          varchar2(256);
    xmlRecord          xmltype;
begin

    xmlRecord := xmltype(iclbRecord);

    rcrRecord.cdplaca                    := zfx_library.fvchgetString4XML(xmlRecord,'CDPLACA');
    rcrRecord.cdcia_usuaria              := zfx_library.fvchgetString4XML(xmlRecord,'CDCIA_USUARIA');
    rcrRecord.feingreso                  := zfx_library.fdtegetDate4XML(xmlRecord,'FEINGRESO');
    rcrRecord.nmtransito_documento       := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMTRANSITO_DOCUMENTO');
    rcrRecord.NMCONSECUTIVO_DOC          := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMCONSECUTIVO_DOC');

    zfstzfw_estados_planilla.Insert$(rcrRecord);

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
    rcrRecord           rtytzfw_estados_planilla;
    nmbErr              number;
    vchErrMsg           varchar2(256);
    xmlRecord           xmltype;
begin

    xmlRecord := xmltype(iclbRecord);

    rcrRecord.cdplaca                    := zfx_library.fvchgetString4XML(xmlRecord,'CDPLACA');
    rcrRecord.cdcia_usuaria              := zfx_library.fvchgetString4XML(xmlRecord,'CDCIA_USUARIA');
    rcrRecord.feingreso                  := zfx_library.fdtegetDate4XML(xmlRecord,'FEINGRESO');
    rcrRecord.nmtransito_documento       := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMTRANSITO_DOCUMENTO');
    rcrRecord.nmconsecutivo_doc          := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMCONSECUTIVO_DOC');
    rcrRecord.nmplanilla                 := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMPLANILLA');
    rcrRecord.cdestado                   := zfx_library.fnmbgetNumber4XML(xmlRecord,'CDPLANILLA');
    rcrRecord.dsplanilla                 := zfx_library.fnmbgetNumber4XML(xmlRecord,'DSPLANILLA');
    rcrRecord.cdusuario                  := zfx_library.fnmbgetNumber4XML(xmlRecord,'CDUSUARIO_REG');
    rcrRecord.id                         := zfx_library.fnmbgetNumber4XML(xmlRecord,  'ID');

    zfstzfw_estados_planilla.Update$(rcrRecord);

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
    rcrRecord           rtytzfw_estados_planilla;
    nmbErr              number;
    vchErrMsg           varchar2(256);
    xmlRecord           xmltype;
begin

    xmlRecord := xmltype(iclbRecord);

    rcrRecord.id                       := zfx_library.fnmbgetNumber4XML(xmlRecord,  'ID');

    zfstzfw_estados_planilla.Delete$(rcrRecord);

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

    zfstzfw_estados_planilla.XQuery(vchFilter,clbXMLResult);

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

------------------------------------------------------ Insert$.prc ----------------------------------------------------
procedure Revision(
    iclbRecord          in      clob,
    oclbXML             out     clob)
is
    rcrRecord          rtytzfw_estados_planilla;
    nmbErr             number;
    vchErrMsg          varchar2(256);
    xmlRecord          xmltype;
begin

    xmlRecord := xmltype(iclbRecord);

    rcrRecord.cdplaca                    := zfx_library.fvchgetString4XML(xmlRecord,'CDPLACA');
    rcrRecord.cdcia_usuaria              := zfx_library.fvchgetString4XML(xmlRecord,'CDCIA_USUARIA');
    rcrRecord.feingreso                  := zfx_library.fdtegetDate4XML(xmlRecord,'FEINGRESO');
    rcrRecord.Nmtransito_Documento       := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMTRANSITO_DOCUMENTO');
    rcrRecord.NMCONSECUTIVO_DOC          := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMCONSECUTIVO_DOC');
    rcrRecord.cdusuario                  := zfx_library.fvchgetString4XML(xmlRecord,'CDUSUARIO');

    zfstzfw_estados_planilla.Revision(rcrRecord, nmbErr, vchErrMsg);

    if (nmbErr is not null) then
        Rollback;
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
        return;
    end if;

    commit;
    vchErrMsg := 'Operacion se completo con exito.';
    oclbXML := zfx_library.fclbsetMessage2XML(7, vchErrMsg);
    return;
end Revision;

------------------------------------------------------ CheckMonitoreoPlaca.prc ----------------------------------------------------
procedure CheckMonitoreoPlaca(
    iclbRecord          in      clob,
    oclbXML             out     clob)
is
    rcrRecord           rtytzfw_estados_planilla;
    nmbErr              number;
    vchErrMsg           varchar2(256);
    xmlRecord           xmltype;
    vcdplaca                    tzfw_estados_planilla.cdplaca%type;
    vcdcia_usuaria              tzfw_estados_planilla.CDCIA_USUARIA%type;
    vfeingreso                  tzfw_estados_planilla.FEINGRESO%type;
    nnmtransito_documento       tzfw_estados_planilla.NMTRANSITO_DOCUMENTO%type;
    nnmconsecutivo_doc          tzfw_estados_planilla.NMCONSECUTIVO_DOC%type;
    ncdusuario                  tzfw_estados_planilla.CDUSUARIO%type;    
begin

    xmlRecord := xmltype(iclbRecord);

    vcdplaca                    := zfx_library.fvchgetString4XML(xmlRecord,'CDPLACA');
    vcdcia_usuaria              := zfx_library.fvchgetString4XML(xmlRecord,'CDCIA_USUARIA');
    vfeingreso                  := zfx_library.fdtegetDate4XML(xmlRecord,'FEINGRESO');
    nnmtransito_documento       := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMTRANSITO_DOCUMENTO');
    nnmconsecutivo_doc          := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMCONSECUTIVO_DOC');
    ncdusuario                  := zfx_library.fvchgetString4XML(xmlRecord,'CDUSUARIO');    

    zfstzfw_estados_planilla.CheckMonitoreoPlaca(vcdplaca,vcdcia_usuaria,vfeingreso,nnmtransito_documento,nnmconsecutivo_doc,ncdusuario, nmbErr, vchErrMsg);

    if (nmbErr is not null) then
        Rollback;
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
        return;
    end if;

    commit;
    vchErrMsg := 'Operacion se completo con exito.';
    oclbXML := zfx_library.fclbsetMessage2XML(7, vchErrMsg);
    return;
end CheckMonitoreoPlaca;

--------------------------------------------------- Create$FromXMLLst.prc ---------------------------------------------
procedure Update$FromXMLLst(
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
                    zfxtzfw_estados_planilla.Insert$(clbRowSet,clbMessage);
             when 'UPDATE' then clbRowSet := '<ROWSET>'||clbRowSrc||'</ROWSET>';
                    zfxtzfw_estados_planilla.Update$(clbRowSet,clbMessage);
             when 'DELETE' then clbRowSet := '<ROWSET>'||clbRowSrc||'</ROWSET>';
                    zfxtzfw_estados_planilla.Delete$(clbRowSet,clbMessage);
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
end Update$FromXMLLst;

--------------------------------------------------- Create$FromXMLLst.prc ---------------------------------------------
procedure UpdateEstadoP$FromXMLLst(
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

              clbRowSet := '<ROWSET>'||clbRowSrc||'</ROWSET>';
              zfxtzfw_estados_planilla.UpdateEstadoPlanilla(clbRowSet,clbMessage);

        blnRowErr := LookupErr$;
        blnRowsErr := blnRowErr or blnRowsErr;
        ConcatMsg$;
        clbRowsetMsg := clbMessage;
        nmbCont := nmbCont +1;
    End loop;
    if (not blnRowsErr) then
        commit;
        ptblNew.delete;
        clbRowsetMsg :=  clbMessage ||chr(10);
        oclbXML := replace(clbRowsetMsg, '<DBX_ACTION>CREATE</DBX_ACTION>',
                                         '<DBX_ACTION>NONE</DBX_ACTION>');
        return;
    end if;
    Rollback;
    clbRowsetMsg := '<ROWSET>' || clbMessage ||'</ROWSET>'||chr(10);
    oclbXML := clbRowsetMsg;
    return;
end UpdateEstadoP$FromXMLLst;



------------------------------------------------------ CheckMonitoreoPlaca.prc ----------------------------------------------------
procedure UpdateEstadoPlanilla(
    iclbRecord          in      clob,
    oclbXML             out     clob)
is
    rcrRecord           rtytzfw_estados_planilla;
    nmbErr              number;
    vchErrMsg           varchar2(2000);
    xmlRecord           xmltype;
    vcdplaca                    tzfw_estados_planilla.cdplaca%type;
    vcdcia_usuaria              tzfw_estados_planilla.CDCIA_USUARIA%type;
    vfeingreso                  varchar2(20);
    nnmtransito_documento       tzfw_estados_planilla.NMTRANSITO_DOCUMENTO%type;
    nnmconsecutivo_doc          tzfw_estados_planilla.NMCONSECUTIVO_DOC%type;
    ncdusuario                  tzfw_estados_planilla.CDUSUARIO%type;
    nnmplanilla                  tzfw_estados_planilla.NMPLANILLA%type;
    vcdestado                    tzfw_estados_planilla.CDESTADO%type;
    vdsplanilla                  tzfw_estados_planilla.DSPLANILLA%type;
    dtFeingreso                  tzfw_estados_planilla.feingreso%type;
    vchCSC                       tzfw_estados_planilla.cdcsc%type;
begin

    xmlRecord := xmltype(iclbRecord);


    vcdplaca                    := zfx_library.fvchgetString4XML(xmlRecord,'CDPLACA');
    vcdcia_usuaria              := zfx_library.fvchgetString4XML(xmlRecord,'CDCIA_USUARIA');
    vfeingreso                  := zfx_library.fvchgetString4XML(xmlRecord,'FEINGRESO');
    nnmtransito_documento       := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMTRANSITO_DOCUMENTO');
    nnmconsecutivo_doc          := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMCONSECUTIVO_DOC');
    nnmplanilla                 := zfx_library.fvchgetString4XML(xmlRecord,'NMPLANILLA');
    vcdestado                   := zfx_library.fvchgetString4XML(xmlRecord,'CDPLANILLA');
    vdsplanilla                 := zfx_library.fvchgetString4XML(xmlRecord,'DSPLANILLA');
    ncdusuario                  := zfx_library.fvchgetString4XML(xmlRecord,'CDUSUARIO');
    vchCSC                      := zfx_library.fvchgetString4XML(xmlRecord,'CDCSC');

    dtFeingreso                 := to_date(vfeingreso,'yyyy-mm-dd hh24:mi:ss');
    zfstzfw_estados_planilla.UpdateEstadoPlanilla(vcdplaca,vcdcia_usuaria,dtFeingreso,nnmtransito_documento,nnmconsecutivo_doc,ncdusuario,nnmplanilla,
                                                    vcdestado,vdsplanilla,vchCSC, nmbErr, vchErrMsg);

    if (nmbErr is not null) then
        Rollback;
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
        return;
    end if;

    commit;

/****************************************************************************************

    Ver        Fecha       Autor              Descripcion
    ---------  ----------  ---------------    ------------------------------------

    3.0        20190213    Guillermo Prieto   Modificacion del paquete para incluir la validacion
                                              En la pantalla de usuario calificado registro
                                              Req 2 Editar y Enviar varias veces una placa
                                              se debe validar que si el usuario ya paso a PENDIENTE el
                                              documento por primera vez de
                                              acuerdo a lo solicitado en el req 2 del documento
                                              F02-PS030223 Especificaci¿n de Requisitos Mejoras 2147 (Planillas).doc.
                                              Se modifica el paquete para incluir el procedimiento ValPendientePriVez
                                              para adicionar la validacion respectiva
                                              Se modifica el paquete para incluir el procedimiento ValTransitoPriVez
                                              para adicionar la validacion respectiva
                                              Se modifica el paquete para incluir la validacion respectiva:
                                              Al cambiar el estado a PENDIENTE debe mostrar mensaje que el estado cambio
                                              a Pendiente y debe guardar auditoria
*****************************************************************************************/
    if vcdestado = 'P' then
       vchErrMsg := 'Operacion se completo con exito. Se cambio a estado Pendiente';
       oclbXML := zfx_library.fclbsetMessage2XML(7, vchErrMsg);
       return;
    else
       vchErrMsg := 'Operacion se completo con exito.';
       oclbXML := zfx_library.fclbsetMessage2XML(7, vchErrMsg);
       return;
    end if;
end UpdateEstadoPlanilla;

------------------------------------------------------ ValSiRealizoEnvio.prc ----------------------------------------------------
/****************************************************************************************

    Ver        Fecha       Autor              Descripcion
    ---------  ----------  ---------------    ------------------------------------

     3.0        20190212    Guillermo Prieto   Modificacion del paquete para incluir la validacion
                                              En la pantalla de usuario calificado registro
                                              Req 2 Editar y Enviar varias veces una placa
                                              se debe validar que si el usuario ya paso a PENDIENTE el
                                              documento por primera vez de
                                              acuerdo a lo solicitado en el req 2 del documento
                                              F02-PS030223 Especificaci¿n de Requisitos Mejoras 2147 (Planillas).doc.
                                              Se modifica el paquete para incluir el procedimiento ValSiRealizoEnvio
                                              para adicionar la validacion respectiva
*****************************************************************************************/
procedure ValSiRealizoEnvio(
    iclbRecord          in      clob,
    oclbXML             out     clob)
is
    rcrRecord                    rtytzfw_estados_planilla;
    nmbErr                       number;
    vchErrMsg                    varchar2(2000);
    xmlRecord                    xmltype;
    clbXMLResult                 clob;
    vchcdcia_usuaria             tzfw_estados_planilla.CDCIA_USUARIA%type;
    vchcdplaca                   tzfw_estados_planilla.CDPLACA%type;
    dtfeingreso                  tzfw_estados_planilla.FEINGRESO%type;
    vchfeingreso                 varchar2(25);
    nmbnmtransito_documento      tzfw_estados_planilla.NMTRANSITO_DOCUMENTO%type;
    nmbnmconsecutivo_doc         tzfw_estados_planilla.NMCONSECUTIVO_DOC%type;
    vchcdcia_usuaria_1           tzfw_estados_planilla.CDCIA_USUARIA%type;
    vchcdplaca_1                 tzfw_estados_planilla.CDPLACA%type;
    dtfeingreso_1                tzfw_estados_planilla.FEINGRESO%type;
    nmbnmtransito_documento_1    tzfw_estados_planilla.NMTRANSITO_DOCUMENTO%type;
    nmbnmconsecutivo_doc_1       tzfw_estados_planilla.NMCONSECUTIVO_DOC%type;
    vchcdcia_usuaria_2           tzfw_estados_planilla.CDCIA_USUARIA%type;
    vchcdplaca_2                 tzfw_estados_planilla.CDPLACA%type;
    dtfeingreso_2                tzfw_estados_planilla.FEINGRESO%type;
    nmbnmtransito_documento_2    tzfw_estados_planilla.NMTRANSITO_DOCUMENTO%type;
    nmbnmconsecutivo_doc_2       tzfw_estados_planilla.NMCONSECUTIVO_DOC%type;
    nmbtransito                  tzfw_transitos_documentos.NMTRANSITO%type;
    nmbSiRealizoEnvio            number   :=0;
    vchcdestado                  varchar2(10)  := ' ';
    nmbResult                    number;
    vchdscia_usuaria             tzfw_cia_usuarias.DSCIA_USUARIA%type   := ' ';
    vchoutdscia_usuaria          varchar2(3000)   := ' ';
    nmbTotRegEstadosPlanilla     number   :=0;
    vchcdcia_usuaria_cia         tzfw_estados_planilla.CDCIA_USUARIA%type   := ' ';


    CURSOR cuTodosTransitoCompanias (icucdplaca                       tzfw_estados_planilla.cdplaca%TYPE,
                                     icudtfeingreso                   tzfw_estados_planilla.feingreso%TYPE,
                                     icunmtransito_documento          tzfw_estados_planilla.nmtransito_documento%TYPE,
                                     icunmbtransito                   tzfw_transitos_documentos.NMTRANSITO%type
     )IS
    SELECT DISTINCT TD.CDCIA_USUARIA, TD.CDPLACA, TD.FEINGRESO, TD.NMTRANSITO_DOCUMENTO
    FROM   TZFW_TRANSITOS_DOCUMENTOS TD
    WHERE  TD.CDPLACA=icucdplaca
    AND    TD.NMTRANSITO=icunmbtransito;

    CURSOR cuRegisDocumXCia  (icucdcia_usuaria                 tzfw_estados_planilla.cdcia_usuaria%TYPE,
                              icucdplaca                       tzfw_estados_planilla.cdplaca%TYPE,
                              icudtfeingreso                   tzfw_estados_planilla.feingreso%TYPE,
                              icunmtransito_documento          tzfw_estados_planilla.nmtransito_documento%TYPE
     )IS
    SELECT DISTINCT DC.CDCIA_USUARIA, DC.CDPLACA, DC.FEINGRESO, DC.NMTRANSITO_DOCUMENTO, DC.NMCONSECUTIVO_DOC
    FROM   TZFW_DOCUMENTOS_X_CIA DC
    WHERE  DC.CDCIA_USUARIA=icucdcia_usuaria
    AND    DC.CDPLACA=icucdplaca
    --AND  DC.FEINGRESO=icudtfeingreso
    AND    DC.NMTRANSITO_DOCUMENTO=icunmtransito_documento;


     CURSOR cuTotRegEstadosPlanilla  (icucdcia_usuaria                 tzfw_estados_planilla.cdcia_usuaria%TYPE,
                                      icucdplaca                       tzfw_estados_planilla.cdplaca%TYPE,
                                      icudtfeingreso                   tzfw_estados_planilla.feingreso%TYPE,
                                      icunmtransito_documento          tzfw_estados_planilla.nmtransito_documento%TYPE,
                                      icunmconsecutivo_doc             tzfw_estados_planilla.nmconsecutivo_doc%TYPE
     )IS
     SELECT SUM(REG_ESTADOS_PLANILLA) REG_ESTADOS_PLANILLA , CDCIA_USUARIA
     FROM
     (
     SELECT COUNT(0) REG_ESTADOS_PLANILLA, CDCIA_USUARIA CDCIA_USUARIA
     FROM TZFW_ESTADOS_PLANILLA T
     WHERE T.CDCIA_USUARIA=icucdcia_usuaria
     AND T.CDPLACA=icucdplaca
     --AND T.FEINGRESO=icudtfeingreso
     AND T.NMTRANSITO_DOCUMENTO=icunmtransito_documento
     AND T.NMCONSECUTIVO_DOC=icunmconsecutivo_doc
     AND T.CDESTADO='T'
     GROUP BY CDCIA_USUARIA
     union  all
     SELECT COUNT(0) REG_ESTADOS_PLANILLA, CDCIA_USUARIA CDCIA_USUARIA
     FROM TZFW_AUDIT_PLANILLA T3
     WHERE T3.CDCIA_USUARIA=icucdcia_usuaria
     AND T3.CDPLACA=icucdplaca
     --AND T3.FEINGRESO=icudtfeingreso
     AND T3.NMTRANSITO_DOCUMENTO=icunmtransito_documento
     AND T3.NMCONSECUTIVO_DOC=icunmconsecutivo_doc
     AND T3.CDVALOR_ANTERIOR='T'
    GROUP BY CDCIA_USUARIA)
    GROUP BY CDCIA_USUARIA;

    CURSOR cuTodasCompanias (icucdplaca                       tzfw_estados_planilla.cdplaca%TYPE,
                             icudtfeingreso                   tzfw_estados_planilla.feingreso%TYPE,
                             icunmtransito_documento          tzfw_estados_planilla.nmtransito_documento%TYPE,
                             icunmbtransito                   tzfw_transitos_documentos.NMTRANSITO%type
     )IS
    SELECT DISTINCT TD.CDCIA_USUARIA
    FROM   TZFW_TRANSITOS_DOCUMENTOS TD
    WHERE  TD.CDPLACA=icucdplaca
    AND    TD.NMTRANSITO=icunmbtransito;
          --AND TD.FEINGRESO=icudtfeingreso
           --AND TD.NMTRANSITO_DOCUMENTO=icunmtransito_documento;

    CURSOR cuCompania (icucdcia_usuaria                 tzfw_audit_planilla.cdcia_usuaria%TYPE
     )IS
     SELECT DSCIA_USUARIA
     FROM   TZFW_CIA_USUARIAS T3
     WHERE  T3.CDCIA_USUARIA=icucdcia_usuaria;

begin
    xmlRecord := xmltype(iclbRecord);
    --rcrRecord := iclbRecord;

    vchcdcia_usuaria                    := zfx_library.fvchgetString4XML(xmlRecord,  'CDCIA_USUARIA');
    vchcdplaca                          := zfx_library.fvchgetString4XML(xmlRecord,  'CDPLACA');
    --dtfeingreso                         := zfx_library.fvchgetString4XML(xmlRecord,  'FEINGRESO');
    vchfeingreso                         := zfx_library.fvchgetString4XML(xmlRecord,  'FEINGRESO');
    nmbnmtransito_documento             := zfx_library.fvchgetString4XML(xmlRecord,  'NMTRANSITO_DOCUMENTO');
    nmbnmconsecutivo_doc                := zfx_library.fvchgetString4XML(xmlRecord,  'NMCONSECUTIVO_DOC');
    nmbtransito                         := zfx_library.fvchgetString4XML(xmlRecord,  'NMTRANSITO');

    zfstzfw_estados_planilla.ValidaSiRealizoEnvio(nmbErr, vchErrMsg, vchcdcia_usuaria, vchcdplaca, dtfeingreso, nmbnmtransito_documento,  nmbnmconsecutivo_doc, nmbtransito, nmbSiRealizoEnvio, vchoutdscia_usuaria);

    if (nmbErr is not null and nmbErr = 154) then
        Open cuTotRegEstadosPlanilla (vchcdcia_usuaria, vchcdplaca, dtfeingreso, nmbnmtransito_documento, nmbnmconsecutivo_doc);
        Fetch cuTotRegEstadosPlanilla Into nmbTotRegEstadosPlanilla, vchcdcia_usuaria_cia;
        Close cuTotRegEstadosPlanilla;

        if nmbTotRegEstadosPlanilla = 0 then
           Open cuTodasCompanias( vchcdplaca, dtfeingreso, nmbnmtransito_documento, nmbtransito);
           Loop
               Exit When cuTodasCompanias%notfound;
               Fetch cuTodasCompanias Into vchdscia_usuaria;

               Open cuCompania (vchcdcia_usuaria);
               Fetch cuCompania Into vchdscia_usuaria;
               Close cuCompania;

               vchdscia_usuaria := vchdscia_usuaria || ', ';
           End loop;
           Close cuTodasCompanias;
        end if;


        vchErrMsg := 'La(s) compania(s) '|| vchoutdscia_usuaria ||' debe(n) enviar la placa para desprecintar';
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
        return;
    end if;

/*****************************************************************************************
    3.0        20190212    Guillermo Prieto   Modificacion del paquete para incluir la validacion
                                              En la pantalla de usuario calificado registro
                                              Req 2 Editar y Enviar varias veces una placa
                                              se debe validar que si el usuario ya paso a PENDIENTE el
                                              documento por primera vez de
                                              acuerdo a lo solicitado en el req 2 del documento
                                              F02-PS030223 Especificaci¿n de Requisitos Mejoras 2147 (Planillas).doc.
                                              Se modifica el paquete para incluir el procedimiento ValSiRealizoEnvio
                                              para adicionar la validacion respectiva
*****************************************************************************************/

    if ( nmbSiRealizoEnvio = -1) then
         nmbErr := 154;
         vchErrMsg := 'La(s) compania(s) '|| vchoutdscia_usuaria ||' debe(n) enviar la placa para desprecintar';
         oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
         return;
    elsif ( nmbSiRealizoEnvio = 0) then
            nmbErr := 0;
            vchErrMsg := ' ';
            oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
            return;
    end if;

    if (nmbResult=-1)then
        oclbXML := zfx_library.fclbsetMessage2XML(154, 'La(s) compania(s)   debe(n) enviar la placa para desprecintar');
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
        return;
    end if;

    return;
end ValSiRealizoEnvio;
--=====================================================================================================================

------------------------------------------------------ ValPendientePriVez.prc ----------------------------------------------------
/****************************************************************************************

    Ver        Fecha       Autor              Descripcion
    ---------  ----------  ---------------    ------------------------------------

    3.0        20190212    Guillermo Prieto   Modificacion del paquete para incluir la validacion
                                              En la pantalla de usuario calificado registro
                                              Req 2 Editar y Enviar varias veces una placa
                                              se debe validar que si el usuario ya paso a PENDIENTE el
                                              documento por primera vez de
                                              acuerdo a lo solicitado en el req 2 del documento
                                              F02-PS030223 Especificaci¿n de Requisitos Mejoras 2147 (Planillas).doc.
                                              Se modifica el paquete para incluir el procedimiento ValPendientePriVez
                                              para adicionar la validacion respectiva
*****************************************************************************************/
procedure ValPendientePriVez(
    iclbRecord          in      clob,
    oclbXML             out     clob)
is
    rcrRecord                    rtytzfw_estados_planilla;
    nmbErr                       number;
    vchErrMsg                    varchar2(2000);
    xmlRecord                    xmltype;
    clbXMLResult                 clob;
    vchCdcia_Usuaria             tzfw_estados_planilla.CDCIA_USUARIA%type;
    vchCdplaca                   tzfw_estados_planilla.CDPLACA%type;
    dtFeingreso                  tzfw_estados_planilla.FEINGRESO%type;
    vchfeingreso                 varchar2(25);
    nmbTransito_Documento        tzfw_estados_planilla.NMTRANSITO_DOCUMENTO%type;
    nmbConsecutivo_Doc           tzfw_estados_planilla.NMCONSECUTIVO_DOC%type;
    nmbValPendientePriVez        number   :=0;
    vchcdestado                  varchar2(10)  := ' ';
    nmbResult                    number;
    vchdscia_usuaria             tzfw_cia_usuarias.DSCIA_USUARIA%type   := ' ';
    vchoutdscia_usuaria          varchar2(3000)   := ' ';
    nmbTotRegEstadosPlanilla     number   :=0;
    vchcdcia_usuaria_cia         tzfw_estados_planilla.CDCIA_USUARIA%type   := ' ';


begin
    xmlRecord := xmltype(iclbRecord);
    --rcrRecord := iclbRecord;

    vchCdcia_Usuaria                    := zfx_library.fvchgetString4XML(xmlRecord,  'CDCIA_USUARIA');
    vchCdplaca                          := zfx_library.fvchgetString4XML(xmlRecord,  'CDPLACA');
    --dtfeingreso                        := zfx_library.fvchgetString4XML(xmlRecord,  'FEINGRESO');
    vchfeingreso                         := zfx_library.fvchgetString4XML(xmlRecord,  'FEINGRESO');
    nmbTransito_Documento                := zfx_library.fvchgetString4XML(xmlRecord,  'NMTRANSITO_DOCUMENTO');
    nmbConsecutivo_Doc                   := zfx_library.fvchgetString4XML(xmlRecord,  'NMCONSECUTIVO_DOC');
    dtFeingreso                          :=  to_date(vchfeingreso,'YYYY-MM-DD HH24:MI:SS');

    zfstzfw_estados_planilla.ValPendientePriVez(nmbErr, vchErrMsg, vchCdcia_Usuaria, vchCdplaca, dtFeingreso, nmbTransito_Documento,  nmbConsecutivo_Doc,  nmbValPendientePriVez);



/*****************************************************************************************
    3.0        20190212    Guillermo Prieto   Modificacion del paquete para incluir la validacion
                                              En la pantalla de usuario calificado registro
                                              Req 2 Editar y Enviar varias veces una placa
                                              se debe validar que si el usuario ya paso a PENDIENTE el
                                              documento por primera vez de
                                              acuerdo a lo solicitado en el req 2 del documento
                                              F02-PS030223 Especificaci¿n de Requisitos Mejoras 2147 (Planillas).doc.
                                              Se modifica el paquete para incluir el procedimiento ValPendientePriVez
                                              para adicionar la validacion respectiva
*****************************************************************************************/

    if ( nmbValPendientePriVez = -1) then
         nmbErr := 154;
         vchErrMsg := ' ';
         oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
         return;
    elsif ( nmbValPendientePriVez = 0) then
            nmbErr := 0;
            vchErrMsg := ' ';
            oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
            return;
    elsif ( nmbValPendientePriVez = 1) then
            nmbErr := 1;
            vchErrMsg := ' ';
            oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
            return;
    end if;

    if (nmbResult=-1)then
        oclbXML := zfx_library.fclbsetMessage2XML(-1, ' ');
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
        return;
    end if;

    return;
end ValPendientePriVez;
--=====================================================================================================================

------------------------------------------------------ ValTransitoPriVez.prc ----------------------------------------------------
/****************************************************************************************

    Ver        Fecha       Autor              Descripcion
    ---------  ----------  ---------------    ------------------------------------

    3.0        20190213    Guillermo Prieto   Modificacion del paquete para incluir la validacion
                                              En la pantalla de usuario calificado registro
                                              Req 2 Editar y Enviar varias veces una placa
                                              se debe validar que si el usuario ya paso a PENDIENTE el
                                              documento por primera vez de
                                              acuerdo a lo solicitado en el req 2 del documento
                                              F02-PS030223 Especificaci¿n de Requisitos Mejoras 2147 (Planillas).doc.
                                              Se modifica el paquete para incluir el procedimiento ValPendientePriVez
                                              para adicionar la validacion respectiva
                                              Se modifica el paquete para incluir el procedimiento ValTransitoPriVez
                                              para adicionar la validacion respectiva
*****************************************************************************************/
procedure ValTransitoPriVez(
    iclbRecord          in      clob,
    oclbXML             out     clob)
is
    rcrRecord                    rtytzfw_estados_planilla;
    nmbErr                       number;
    vchErrMsg                    varchar2(2000);
    xmlRecord                    xmltype;
    clbXMLResult                 clob;
    vchCdcia_Usuaria             tzfw_estados_planilla.CDCIA_USUARIA%type;
    vchCdplaca                   tzfw_estados_planilla.CDPLACA%type;
    dtFeingreso                  tzfw_estados_planilla.FEINGRESO%type;
    vchfeingreso                 varchar2(25);
    nmbTransito_Documento        tzfw_estados_planilla.NMTRANSITO_DOCUMENTO%type;
    nmbConsecutivo_Doc           tzfw_estados_planilla.NMCONSECUTIVO_DOC%type;
    nmbValTransitoPriVez         number   :=0;
    vchcdestado                  varchar2(10)  := ' ';
    nmbResult                    number;
    vchdscia_usuaria             tzfw_cia_usuarias.DSCIA_USUARIA%type   := ' ';
    vchoutdscia_usuaria          varchar2(3000)   := ' ';
    nmbTotRegEstadosPlanilla     number   :=0;
    vchcdcia_usuaria_cia         tzfw_estados_planilla.CDCIA_USUARIA%type   := ' ';


begin
    xmlRecord := xmltype(iclbRecord);
    --rcrRecord := iclbRecord;

    vchCdcia_Usuaria                    := zfx_library.fvchgetString4XML(xmlRecord,  'CDCIA_USUARIA');
    vchCdplaca                          := zfx_library.fvchgetString4XML(xmlRecord,  'CDPLACA');
    --dtfeingreso                        := zfx_library.fvchgetString4XML(xmlRecord,  'FEINGRESO');
    vchfeingreso                         := zfx_library.fvchgetString4XML(xmlRecord,  'FEINGRESO');
    nmbTransito_Documento                := zfx_library.fvchgetString4XML(xmlRecord,  'NMTRANSITO_DOCUMENTO');
    nmbConsecutivo_Doc                   := zfx_library.fvchgetString4XML(xmlRecord,  'NMCONSECUTIVO_DOC');
    dtFeingreso                          :=  to_date(vchfeingreso,'YYYY-MM-DD HH24:MI:SS');

    zfstzfw_estados_planilla.ValTransitoPriVez(nmbErr, vchErrMsg, vchCdcia_Usuaria, vchCdplaca, dtFeingreso, nmbTransito_Documento,  nmbConsecutivo_Doc,  nmbValTransitoPriVez);



/*****************************************************************************************
     3.0        20190213    Guillermo Prieto   Modificacion del paquete para incluir la validacion
                                              En la pantalla de usuario calificado registro
                                              Req 2 Editar y Enviar varias veces una placa
                                              se debe validar que si el usuario ya paso a PENDIENTE el
                                              documento por primera vez de
                                              acuerdo a lo solicitado en el req 2 del documento
                                              F02-PS030223 Especificaci¿n de Requisitos Mejoras 2147 (Planillas).doc.
                                              Se modifica el paquete para incluir el procedimiento ValPendientePriVez
                                              para adicionar la validacion respectiva
                                              Se modifica el paquete para incluir el procedimiento ValTransitoPriVez
                                              para adicionar la validacion respectiva
*****************************************************************************************/

    if ( nmbValTransitoPriVez = -1) then
         nmbErr := 154;
         vchErrMsg := ' ';
         oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
         return;
    elsif ( nmbValTransitoPriVez = 0) then
            nmbErr := 0;
            vchErrMsg := ' ';
            oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
            return;
    elsif ( nmbValTransitoPriVez = 1) then
            nmbErr := 1;
            vchErrMsg := ' ';
            oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
            return;
    end if;

    if (nmbResult=-1)then
        oclbXML := zfx_library.fclbsetMessage2XML(-1, ' ');
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
        return;
    end if;

    return;
end ValTransitoPriVez;
--=====================================================================================================================


begin
    null;
end zfxtzfw_estados_planilla;
