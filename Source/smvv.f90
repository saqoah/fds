MODULE ISOSMOKE
!> \brief Collection of routines to output data to smokeview.

USE PRECISION_PARAMETERS

IMPLICIT NONE (TYPE,EXTERNAL)

PRIVATE
PUBLIC ISO_TO_FILE,SMOKE3D_TO_FILE, SLICE_TO_RLEFILE

CONTAINS

! ----------------------- ISO_TO_FILE -------------------------


!> \brief Routine to output compute an isosurface and output it to a file.

SUBROUTINE ISO_TO_FILE(LU_ISO,LU_ISO2, NM,IBAR, JBAR, KBAR, T,VDATA, VDATA2, HAVE_ISO2, LEVELS, NLEVELS, IBLANK, SKIP, DELTA, &
                       XPLT, NX, YPLT, NY, ZPLT, NZ)
  USE TRAN, ONLY : GET_IJK
  USE BOXTETRA_ROUTINES, ONLY : DECIMATE_FB

  INTEGER, INTENT(IN) :: NX, NY, NZ, NM, IBAR, JBAR, KBAR
  INTEGER, INTENT(INOUT) :: LU_ISO, LU_ISO2
  REAL(FB), INTENT(IN) :: T
  REAL(FB), INTENT(IN), DIMENSION(0:NX,0:NY,0:NZ) :: VDATA, VDATA2
  INTEGER, INTENT(IN), DIMENSION(NX-1,NY-1,NZ-1) :: IBLANK
  INTEGER, INTENT(IN) :: HAVE_ISO2
  INTEGER, INTENT(IN) :: SKIP
  REAL(FB), INTENT(IN) :: DELTA
  INTEGER, INTENT(IN) :: NLEVELS
  REAL(FB), INTENT(IN), DIMENSION(NLEVELS) :: LEVELS
  REAL(FB), INTENT(IN), DIMENSION(NX) :: XPLT
  REAL(FB), INTENT(IN), DIMENSION(NY) :: YPLT
  REAL(FB), INTENT(IN), DIMENSION(NZ) :: ZPLT

  INTEGER :: I, J, K, IJK
  INTEGER :: NXYZVERTS, NTRIANGLES, NXYZVERTS_ALL, NTRIANGLES_ALL
  REAL(FB), DIMENSION(:), ALLOCATABLE :: XYZVERTS
  INTEGER, DIMENSION(:), ALLOCATABLE :: TRIANGLES, LEVEL_INDICES
  REAL(FB), DIMENSION(:), ALLOCATABLE, TARGET :: XYZVERTS_ALL
  REAL(FB), DIMENSION(:), ALLOCATABLE  :: VALVERTS_ALL
  INTEGER, DIMENSION(:), ALLOCATABLE :: TRIANGLES_ALL, LEVEL_INDICES_ALL
  REAL(EB) :: XI, YJ, ZK, XX, YY, ZZ
  REAL(EB) :: X_WGT, Y_WGT, Z_WGT
  REAL(EB) :: V11, V12, V21, V22, V1, V2
  INTEGER :: IP1, JP1, KP1
  REAL(FB), DIMENSION(6) :: MESH_BOUNDS

  INTEGER :: ONE=1, VERSION=1

  NXYZVERTS_ALL=0
  NTRIANGLES_ALL=0

  DO I =1, NLEVELS
    CALL ISO_TO_GEOM(VDATA, LEVELS(I), IBLANK, SKIP, XPLT, NX, YPLT, NY, ZPLT, NZ, XYZVERTS, NXYZVERTS, TRIANGLES, NTRIANGLES)
    IF (NTRIANGLES>0.AND.NXYZVERTS>0) THEN
      ALLOCATE(LEVEL_INDICES(NTRIANGLES))
      LEVEL_INDICES=I
      CALL MERGE_GEOM(TRIANGLES_ALL,LEVEL_INDICES_ALL,NTRIANGLES_ALL,XYZVERTS_ALL,NXYZVERTS_ALL,&
           TRIANGLES,LEVEL_INDICES,NTRIANGLES,XYZVERTS,NXYZVERTS)
      DEALLOCATE(LEVEL_INDICES)
    ENDIF
    DEALLOCATE(XYZVERTS) ! these variables were allocated in ISO_TO_GEOM
    DEALLOCATE(TRIANGLES)
  END DO
  IF (NXYZVERTS_ALL>0.AND.NTRIANGLES_ALL>0) THEN
    CALL REMOVE_DUPLICATE_ISO_VERTS(XYZVERTS_ALL,NXYZVERTS_ALL,TRIANGLES_ALL,NTRIANGLES_ALL)
  ENDIF

  ! isosurface geometry was generated from a routine originally written in C which uses array indices that start at 0
  ! add 1 to be compatible with Fortran (which start array indices at 1)

  IF (NTRIANGLES_ALL>0) THEN
     TRIANGLES_ALL(1:3*NTRIANGLES_ALL) = 1 + TRIANGLES_ALL(1:3*NTRIANGLES_ALL) 
  ENDIF

  IF (DELTA > 0.0_FB) THEN
    MESH_BOUNDS(1) = XPLT(1)
    MESH_BOUNDS(2) = XPLT(NX)
    MESH_BOUNDS(3) = YPLT(1)
    MESH_BOUNDS(4) = YPLT(NY)
    MESH_BOUNDS(5) = ZPLT(1)
    MESH_BOUNDS(6) = ZPLT(NZ)
    CALL DECIMATE_FB(XYZVERTS_ALL, NXYZVERTS_ALL, TRIANGLES_ALL, NTRIANGLES_ALL, MESH_BOUNDS, DELTA)
  ENDIF
  IF (LU_ISO<0) THEN
    LU_ISO  = ABS(LU_ISO)
    CALL ISO_HEADER_OUT(LU_ISO,LEVELS,NLEVELS)
  ENDIF
  IF (HAVE_ISO2 .EQ. 1 .AND. LU_ISO2<0) THEN
    LU_ISO2 = ABS(LU_ISO2)
    ! output header for isosurface values file
    WRITE(LU_ISO2)ONE
    WRITE(LU_ISO2)VERSION
  ENDIF
  IF (HAVE_ISO2 .EQ. 1 .AND. NXYZVERTS_ALL > 0 .AND. NTRIANGLES_ALL>0) THEN
     ALLOCATE(VALVERTS_ALL(NXYZVERTS_ALL))
     DO IJK = 1, NXYZVERTS_ALL
        XX=REAL(XYZVERTS_ALL(3*IJK-2),EB)
        YY=REAL(XYZVERTS_ALL(3*IJK-1),EB)
        ZZ=REAL(XYZVERTS_ALL(3*IJK),EB)
        CALL GET_IJK(XX,YY,ZZ,NM,XI,YJ,ZK,I,J,K)
        X_WGT = MAX(0.0_EB,MIN(XI - FLOOR(XI),1.0_EB))
        Y_WGT = MAX(0.0_EB,MIN(YJ - FLOOR(YJ),1.0_EB))
        Z_WGT = MAX(0.0_EB,MIN(ZK - FLOOR(ZK),1.0_EB))
        IP1 = MIN(I+1,IBAR)
        JP1 = MIN(J+1,JBAR)
        KP1 = MIN(K+1,KBAR)

        V11 = VDATA2(I,  J,  K)*(1.0-X_WGT) + VDATA2(IP1,  J,  K)*X_WGT 
        V21 = VDATA2(I,JP1,  K)*(1.0-X_WGT) + VDATA2(IP1,JP1,  K)*X_WGT
        V12 = VDATA2(I,  J,KP1)*(1.0-X_WGT) + VDATA2(IP1,  J,KP1)*X_WGT 
        V22 = VDATA2(I,JP1,KP1)*(1.0-X_WGT) + VDATA2(IP1,JP1,KP1)*X_WGT 
        V1 = V11*(1.0-Y_WGT) + V21*Y_WGT
        V2 = V12*(1.0-Y_WGT) + V22*Y_WGT
        VALVERTS_ALL(IJK) = REAL(V1*(1.0-Z_WGT) + V2*Z_WGT,FB)
     END DO
  ENDIF

  CALL ISO_OUT_TIME(LU_ISO,T,NXYZVERTS_ALL,NTRIANGLES_ALL)
  IF (NXYZVERTS_ALL > 0 .AND. NTRIANGLES_ALL>0) THEN
     CALL ISO_OUT_GEOM(LU_ISO,XYZVERTS_ALL,NXYZVERTS_ALL,TRIANGLES_ALL,LEVEL_INDICES_ALL,NTRIANGLES_ALL)
     IF (HAVE_ISO2 .EQ. 1) THEN
        CALL ISO_OUT_VALS(LU_ISO2,T,VALVERTS_ALL,NXYZVERTS_ALL)
        DEALLOCATE(VALVERTS_ALL)
     ENDIF
     DEALLOCATE(XYZVERTS_ALL)
     DEALLOCATE(LEVEL_INDICES_ALL)
     DEALLOCATE(TRIANGLES_ALL)
  ENDIF

END SUBROUTINE ISO_TO_FILE

! ----------------------- COMPARE_VEC3 -------------------------

!> \brief Routine to compare two 3-vectors.
!> The integer 1 is returned if the two vectors are the same within DELTA.

INTEGER FUNCTION COMPARE_VEC3(XI,XJ)
REAL(FB), INTENT(IN), DIMENSION(3) :: XI, XJ
REAL(FB) :: DELTA=0.0001_FB
COMPARE_VEC3 = 0
IF (ABS(XI(1)-XJ(1)) > DELTA) RETURN
IF (ABS(XI(2)-XJ(2)) > DELTA) RETURN
IF (ABS(XI(3)-XJ(3)) > DELTA) RETURN
COMPARE_VEC3 = 1
END FUNCTION COMPARE_VEC3

! ----------------------- GET_MATCH -------------------------

!> \brief Routine to find the index (if any) of a 3-vector that matches a given 3-vector.

INTEGER FUNCTION GET_MATCH(IFROM,VERTS,ITOVERTS,NVERTS)

  INTEGER, INTENT(IN) :: IFROM, ITOVERTS, NVERTS
  REAL(FB), INTENT(IN), DIMENSION(3*NVERTS), TARGET :: VERTS
  REAL(FB), DIMENSION(:), POINTER :: XYZI, XYZFROM
  INTEGER :: I

  GET_MATCH=0
  XYZFROM=>VERTS(3*IFROM-2:3*IFROM)
  DO I = 1, ITOVERTS
    XYZI => VERTS(3*I-2:3*I)
    IF (COMPARE_VEC3(XYZFROM,XYZI)==1) THEN
      GET_MATCH=I
      RETURN
    ENDIF
  END DO
END FUNCTION GET_MATCH

! ----------------------- REMOVE_DUPLICATE_ISO_VERTS -------------------------

!> \brief Routine to remove dupicate isosurface vertices.

SUBROUTINE REMOVE_DUPLICATE_ISO_VERTS(VERTS,NVERTS,TRIANGLES,NTRIANGLES)

REAL(FB), INTENT(INOUT), DIMENSION(:)  :: VERTS
INTEGER, INTENT(INOUT), DIMENSION(:) :: TRIANGLES
INTEGER, INTENT(IN) :: NTRIANGLES
INTEGER, INTENT(INOUT) :: NVERTS

INTEGER, ALLOCATABLE, DIMENSION(:) :: MAPVERTS
INTEGER :: I,NVERTS_OLD,IFROM,ITO
INTEGER :: IMATCH

NVERTS_OLD = NVERTS

IF (NVERTS==0.OR.NTRIANGLES==0)RETURN
ALLOCATE(MAPVERTS(NVERTS))

MAPVERTS(1)=1
ITO=2
DO IFROM=2, NVERTS
  IMATCH = GET_MATCH(IFROM,VERTS,ITO-1,NVERTS)
  IF (IMATCH/=0) THEN
    MAPVERTS(IFROM)=IMATCH
    CYCLE
  ENDIF
  MAPVERTS(IFROM)=ITO
  VERTS(3*ITO-2:3*ITO)=VERTS(3*IFROM-2:3*IFROM)
  ITO = ITO + 1
END DO
NVERTS=ITO-1

! MAP TRIANGLE NODES TO NEW NODES

DO I=1,3*NTRIANGLES
  TRIANGLES(I) = MAPVERTS(TRIANGLES(I) + 1) - 1
END DO

DEALLOCATE(MAPVERTS)

END SUBROUTINE REMOVE_DUPLICATE_ISO_VERTS

! ----------------------- ISO_TO_GEOM -------------------------

!> \brief Routine to geneate an isosurface and store it in a geometry format (vertices/faces).

SUBROUTINE ISO_TO_GEOM(VDATA, LEVEL, IBLANK_CELL, SKIP, XPLT, NX, YPLT, NY, ZPLT, NZ, &
                       XYZVERTS, NXYZVERTS, TRIANGLES, NTRIANGLES)
  INTEGER, INTENT(IN) :: NX, NY, NZ
  REAL(FB), DIMENSION(NX+1,NY+1,NZ+1), INTENT(IN) :: VDATA
  INTEGER, DIMENSION(NX-1,NY-1,NZ-1), INTENT(IN) :: IBLANK_CELL
  INTEGER, INTENT(IN) :: SKIP
  REAL(FB), INTENT(IN) :: LEVEL
  REAL(FB), INTENT(IN), DIMENSION(NX) :: XPLT
  REAL(FB), INTENT(IN), DIMENSION(NY) :: YPLT
  REAL(FB), INTENT(IN), DIMENSION(NZ) :: ZPLT

  REAL(FB), INTENT(OUT), DIMENSION(:), ALLOCATABLE :: XYZVERTS
  INTEGER, INTENT(OUT), DIMENSION(:), ALLOCATABLE :: TRIANGLES
  INTEGER, INTENT(OUT) :: NTRIANGLES, NXYZVERTS

  REAL(FB), DIMENSION(0:1) :: XX, YY, ZZ
  REAL(FB), DIMENSION(0:7) :: VALS
  REAL(FB), DIMENSION(0:35) :: XYZVERTS_LOCAL
  INTEGER :: NXYZVERTS_LOCAL
  INTEGER, DIMENSION(0:14) :: TRIS_LOCAL
  INTEGER :: NTRIS_LOCAL
  INTEGER :: NXYZVERTS_MAX, NTRIANGLES_MAX
  REAL(FB) :: VMIN, VMAX
  INTEGER :: I, J, K
  INTEGER :: IP1, JP1, KP1

  NTRIANGLES=0
  NXYZVERTS=0
  NXYZVERTS_MAX=1000
  NTRIANGLES_MAX=1000
  ALLOCATE(XYZVERTS(3*NXYZVERTS_MAX))
  ALLOCATE(TRIANGLES(3*NTRIANGLES_MAX))

  DO I=1, NX-1, SKIP
    IP1 = MIN(I+SKIP,NX)
    XX(0) = XPLT(I)
    XX(1) = XPLT(IP1)
    DO J=1, NY-1, SKIP
      JP1 = MIN(J+SKIP,NY)
      YY(0) = YPLT(J);
      YY(1) = YPLT(JP1);
      DO K=1, NZ-1, SKIP
        IF (IBLANK_CELL(I,J,K) == 0) CYCLE

        KP1 = MIN(K+SKIP,NZ)

        VALS(0) = VDATA(  I,  J,  K)
        VALS(1) = VDATA(  I,JP1,  K)
        VALS(2) = VDATA(IP1,JP1,  K)
        VALS(3) = VDATA(IP1,  J,  K)
        VALS(4) = VDATA(  I,  J,KP1)
        VALS(5) = VDATA(  I,JP1,KP1)
        VALS(6) = VDATA(IP1,JP1,KP1)
        VALS(7) = VDATA(IP1,  J,KP1)

        VMIN = MIN(VALS(0),VALS(1),VALS(2),VALS(3),VALS(4),VALS(5),VALS(6),VALS(7))
        VMAX = MAX(VALS(0),VALS(1),VALS(2),VALS(3),VALS(4),VALS(5),VALS(6),VALS(7))
        IF (VMIN > LEVEL.OR.VMAX < LEVEL) CYCLE

        ZZ(0) = ZPLT(K);
        ZZ(1) = ZPLT(KP1);

        CALL GETISOBOX(XX,YY,ZZ,VALS,LEVEL,&
            XYZVERTS_LOCAL,NXYZVERTS_LOCAL,TRIS_LOCAL,NTRIS_LOCAL)

        IF (NXYZVERTS_LOCAL > 0.OR.NTRIS_LOCAL > 0) THEN
          CALL UPDATEISOSURFACE(XYZVERTS_LOCAL, NXYZVERTS_LOCAL, TRIS_LOCAL, NTRIS_LOCAL, &
          XYZVERTS, NXYZVERTS, NXYZVERTS_MAX, TRIANGLES, NTRIANGLES, NTRIANGLES_MAX)
        ENDIF
      END DO
    END DO
  END DO
END SUBROUTINE ISO_TO_GEOM

! ----------------------- ISO_HEADER_OUT -------------------------

!> \brief Routine to output the header portion of an isosurface file.

SUBROUTINE ISO_HEADER_OUT(LU_ISO,ISO_LEVELS,NISO_LEVELS)

  INTEGER, INTENT(IN) :: NISO_LEVELS
  INTEGER, INTENT(IN) :: LU_ISO
  REAL(FB), INTENT(IN), DIMENSION(NISO_LEVELS) :: ISO_LEVELS

  INTEGER :: VERSION=1
  INTEGER :: I
  INTEGER :: ONE=1,ZERO=0

  WRITE(LU_ISO) ONE
  WRITE(LU_ISO) VERSION
  WRITE(LU_ISO) NISO_LEVELS
  IF (NISO_LEVELS>0) WRITE(LU_ISO) (ISO_LEVELS(I),I=1,NISO_LEVELS)
  WRITE(LU_ISO) ZERO  ! no integer header
  WRITE(LU_ISO) ZERO, ZERO  ! no static nodes or triangles
END SUBROUTINE ISO_HEADER_OUT

! ----------------------- ISO_OUT_TIME -------------------------

!> \brief Routine to output the time, number of vertices and faces to an isosurface file.

SUBROUTINE ISO_OUT_TIME(LU_ISO,STIME,NVERTS,NTRIANGLES)
  INTEGER, INTENT(IN) :: LU_ISO
  REAL(FB), INTENT(IN) :: STIME
  INTEGER, INTENT(IN) :: NVERTS,  NTRIANGLES

  INTEGER :: GEOM_TYPE=0, NVERTS_COPY, NTRIANGLES_COPY

  ! only output vertics if there are triangles and visa versa

  NVERTS_COPY = NVERTS
  NTRIANGLES_COPY = NTRIANGLES
  IF (NTRIANGLES .EQ. 0) NVERTS_COPY=0
  IF (NVERTS .EQ. 0) NTRIANGLES_COPY = 0

  WRITE(LU_ISO) STIME, GEOM_TYPE ! dynamic geometry (displayed only at time STIME)
  WRITE(LU_ISO) NVERTS_COPY,NTRIANGLES_COPY
END SUBROUTINE ISO_OUT_TIME

! ----------------------- ISO_OUT_GEOM -------------------------

!> \brief Routine to output the vertices and faces to an isosurface file.

SUBROUTINE ISO_OUT_GEOM(LU_ISO,VERTS,NVERTS,TRIANGLES,SURFACES,NTRIANGLES)
  INTEGER, INTENT(IN) :: LU_ISO
  INTEGER, INTENT(IN) :: NVERTS,  NTRIANGLES
  REAL(FB), INTENT(IN), DIMENSION(:) :: VERTS
  INTEGER, INTENT(IN), DIMENSION(:) :: TRIANGLES
  INTEGER, INTENT(IN), DIMENSION(:) :: SURFACES

  INTEGER :: I

  IF (NVERTS>0) THEN
     WRITE(LU_ISO) (VERTS(I),I=1,3*NVERTS)
  ENDIF
  IF (NTRIANGLES>0) THEN
     WRITE(LU_ISO) (TRIANGLES(I),I=1,3*NTRIANGLES)
     WRITE(LU_ISO) (SURFACES(I),I=1,NTRIANGLES)
  ENDIF
END SUBROUTINE ISO_OUT_GEOM

! ----------------------- ISO_OUT_VALS -------------------------

!> \brief Routine to output the data values at vertices to an isosurface file.

SUBROUTINE ISO_OUT_VALS(LU_ISO2,STIME,VALS,NVERTS)
  INTEGER, INTENT(IN) :: LU_ISO2
  REAL(FB), INTENT(IN) :: STIME
  INTEGER, INTENT(IN) :: NVERTS
  REAL(FB), INTENT(IN), DIMENSION(:) :: VALS

  INTEGER :: I

  WRITE(LU_ISO2)STIME
  WRITE(LU_ISO2)0,0,NVERTS,0  ! only output data at vertices (not at triangles)
  IF (NVERTS > 0) WRITE(LU_ISO2)(VALS(I),I=1,NVERTS)
END SUBROUTINE ISO_OUT_VALS

! ----------------------- MERGE_GEOM -------------------------

!> \brief Routine to combine two sets of vertices and surfaces into one. 

SUBROUTINE MERGE_GEOM(  TRIS_TO,  SURFACES_TO,  NTRIS_TO,  NODES_TO,  NNODES_TO,&
                      TRIS_FROM,SURFACES_FROM,NTRIS_FROM,NODES_FROM,NNODES_FROM)

  INTEGER, INTENT(INOUT), DIMENSION(:), ALLOCATABLE :: TRIS_TO, SURFACES_TO
  REAL(FB), INTENT(INOUT), DIMENSION(:), ALLOCATABLE :: NODES_TO
  INTEGER, INTENT(INOUT) :: NTRIS_TO,NNODES_TO

  INTEGER, DIMENSION(:) :: TRIS_FROM, SURFACES_FROM
  REAL(FB), DIMENSION(:) :: NODES_FROM
  INTEGER, INTENT(IN) :: NTRIS_FROM,NNODES_FROM

  INTEGER :: NNODES_NEW, NTRIS_NEW, N

  NNODES_NEW = NNODES_TO + NNODES_FROM
  NTRIS_NEW = NTRIS_TO + NTRIS_FROM

  CALL REALLOCATE_F(NODES_TO,3*NNODES_TO,3*NNODES_NEW)
  CALL REALLOCATE_I(TRIS_TO,3*NTRIS_TO,3*NTRIS_NEW)
  CALL REALLOCATE_I(SURFACES_TO,NTRIS_TO,NTRIS_NEW)

  NODES_TO(1+3*NNODES_TO:3*NNODES_NEW) = NODES_FROM(1:3*NNODES_FROM)
  TRIS_TO(1+3*NTRIS_TO:3*NTRIS_NEW) = TRIS_FROM(1:3*NTRIS_FROM)
  SURFACES_TO(1+NTRIS_TO:NTRIS_NEW) = SURFACES_FROM(1:NTRIS_FROM)

  DO N=1,3*NTRIS_FROM
    TRIS_TO(3*NTRIS_TO+N) = TRIS_TO(3*NTRIS_TO+N) + NNODES_TO
  END DO
  NNODES_TO = NNODES_NEW
  NTRIS_TO = NTRIS_NEW
END SUBROUTINE MERGE_GEOM

! ----------------------- GETISOBOX -------------------------

!> \brief Routine to determine the isosurface if any that passes through a grid cell. 

SUBROUTINE GETISOBOX(X,Y,Z,VALS,LEVEL,XYZV_LOCAL,NXYZV,TRIS,NTRIS)

  REAL(FB), DIMENSION(0:1), INTENT(IN) :: X, Y, Z
  REAL(FB), DIMENSION(0:7), INTENT(IN) :: VALS
  REAL(FB), INTENT(OUT), DIMENSION(0:35) :: XYZV_LOCAL
  INTEGER, INTENT(OUT), DIMENSION(0:14) :: TRIS
  REAL(FB), INTENT(IN) :: LEVEL
  INTEGER, INTENT(OUT) :: NXYZV
  INTEGER, INTENT(OUT) :: NTRIS
  INTEGER :: I, J
  INTEGER, DIMENSION(0:14) :: COMPCASE=(/0,0,0,-1,0,0,-1,-1,0,0,0,0,-1,-1,0/)
  INTEGER, DIMENSION(0:11,0:1) :: EDGE2VERTEX
  INTEGER, DIMENSION(0:1,0:11) :: EDGE2VERTEXTT
  DATA ((EDGE2VERTEXTT(I,J),I=0,1),J=0,11) /0,1,1,2,2,3,0,3,&
                                              0,4,1,5,2,6,3,7,&
                                              4,5,5,6,6,7,4,7/
  INTEGER, POINTER, DIMENSION(:) :: CASE2
  INTEGER, TARGET,DIMENSION(0:255,0:9) :: CASES
  INTEGER, DIMENSION(0:9,0:255) :: CASEST
  DATA ((CASEST(I,J),I=0,9),J=0,255) /&
  0,0,0,0,0,0,0,0, 0,  0,0,1,2,3,4,5,6,7, 1,  1,1,2,3,0,5,6,7,4, 1,  2,&
  1,2,3,0,5,6,7,4, 2,  3,2,3,0,1,6,7,4,5, 1,  4,0,4,5,1,3,7,6,2, 3,  5,&
  2,3,0,1,6,7,4,5, 2,  6,3,0,1,2,7,4,5,6, 5,  7,3,0,1,2,7,4,5,6, 1,  8,&
  0,1,2,3,4,5,6,7, 2,  9,3,7,4,0,2,6,5,1, 3, 10,2,3,0,1,6,7,4,5, 5, 11,&
  3,0,1,2,7,4,5,6, 2, 12,1,2,3,0,5,6,7,4, 5, 13,0,1,2,3,4,5,6,7, 5, 14,&
  0,1,2,3,4,5,6,7, 8, 15,4,0,3,7,5,1,2,6, 1, 16,4,5,1,0,7,6,2,3, 2, 17,&
  1,2,3,0,5,6,7,4, 3, 18,5,1,0,4,6,2,3,7, 5, 19,2,3,0,1,6,7,4,5, 4, 20,&
  4,5,1,0,7,6,2,3, 6, 21,2,3,0,1,6,7,4,5, 6, 22,3,0,1,2,7,4,5,6,14, 23,&
  4,5,1,0,7,6,2,3, 3, 24,7,4,0,3,6,5,1,2, 5, 25,2,6,7,3,1,5,4,0, 7, 26,&
  3,0,1,2,7,4,5,6, 9, 27,2,6,7,3,1,5,4,0, 6, 28,4,0,3,7,5,1,2,6,11, 29,&
  0,1,2,3,4,5,6,7,12, 30,0,0,0,0,0,0,0,0, 0,  0,5,4,7,6,1,0,3,2, 1, 32,&
  0,3,7,4,1,2,6,5, 3, 33,1,0,4,5,2,3,7,6, 2, 34,4,5,1,0,7,6,2,3, 5, 35,&
  2,3,0,1,6,7,4,5, 3, 36,3,7,4,0,2,6,5,1, 7, 37,6,2,1,5,7,3,0,4, 5, 38,&
  0,1,2,3,4,5,6,7, 9, 39,3,0,1,2,7,4,5,6, 4, 40,3,7,4,0,2,6,5,1, 6, 41,&
  5,6,2,1,4,7,3,0, 6, 42,3,0,1,2,7,4,5,6,11, 43,3,0,1,2,7,4,5,6, 6, 44,&
  1,2,3,0,5,6,7,4,12, 45,0,1,2,3,4,5,6,7,14, 46,0,0,0,0,0,0,0,0, 0,  0,&
  5,1,0,4,6,2,3,7, 2, 48,1,0,4,5,2,3,7,6, 5, 49,0,4,5,1,3,7,6,2, 5, 50,&
  4,5,1,0,7,6,2,3, 8, 51,4,7,6,5,0,3,2,1, 6, 52,1,0,4,5,2,3,7,6,12, 53,&
  4,5,1,0,7,6,2,3,11, 54,0,0,0,0,0,0,0,0, 0,  0,5,1,0,4,6,2,3,7, 6, 56,&
  1,0,4,5,2,3,7,6,14, 57,0,4,5,1,3,7,6,2,12, 58,0,0,0,0,0,0,0,0, 0,  0,&
  4,0,3,7,5,1,2,6,10, 60,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,6,7,3,2,5,4,0,1, 1, 64,0,1,2,3,4,5,6,7, 4, 65,&
  1,0,4,5,2,3,7,6, 3, 66,0,4,5,1,3,7,6,2, 6, 67,2,1,5,6,3,0,4,7, 2, 68,&
  6,7,3,2,5,4,0,1, 6, 69,5,6,2,1,4,7,3,0, 5, 70,0,1,2,3,4,5,6,7,11, 71,&
  3,0,1,2,7,4,5,6, 3, 72,0,1,2,3,4,5,6,7, 6, 73,7,4,0,3,6,5,1,2, 7, 74,&
  2,3,0,1,6,7,4,5,12, 75,7,3,2,6,4,0,1,5, 5, 76,1,2,3,0,5,6,7,4,14, 77,&
  1,2,3,0,5,6,7,4, 9, 78,0,0,0,0,0,0,0,0, 0,  0,4,0,3,7,5,1,2,6, 3, 80,&
  0,3,7,4,1,2,6,5, 6, 81,2,3,0,1,6,7,4,5, 7, 82,5,1,0,4,6,2,3,7,12, 83,&
  2,1,5,6,3,0,4,7, 6, 84,0,1,2,3,4,5,6,7,10, 85,5,6,2,1,4,7,3,0,12, 86,&
  0,0,0,0,0,0,0,0, 0,  0,0,1,2,3,4,5,6,7, 7, 88,7,4,0,3,6,5,1,2,12, 89,&
  3,0,1,2,7,4,5,6,13, 90,0,0,0,0,0,0,0,0, 0,  0,7,3,2,6,4,0,1,5,12, 92,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  5,4,7,6,1,0,3,2, 2, 96,6,2,1,5,7,3,0,4, 6, 97,2,1,5,6,3,0,4,7, 5, 98,&
  2,1,5,6,3,0,4,7,14, 99,1,5,6,2,0,4,7,3, 5,100,1,5,6,2,0,4,7,3,12,101,&
  1,5,6,2,0,4,7,3, 8,102,0,0,0,0,0,0,0,0, 0,  0,5,4,7,6,1,0,3,2, 6,104,&
  0,4,5,1,3,7,6,2,10,105,2,1,5,6,3,0,4,7,12,106,0,0,0,0,0,0,0,0, 0,  0,&
  5,6,2,1,4,7,3,0,11,108,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,7,6,5,4,3,2,1,0, 5,112,0,4,5,1,3,7,6,2,11,113,&
  6,5,4,7,2,1,0,3, 9,114,0,0,0,0,0,0,0,0, 0,  0,1,5,6,2,0,4,7,3,14,116,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  7,6,5,4,3,2,1,0,12,120,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,7,6,5,4,3,2,1,0, 1,128,&
  0,1,2,3,4,5,6,7, 3,129,1,2,3,0,5,6,7,4, 4,130,1,2,3,0,5,6,7,4, 6,131,&
  7,4,0,3,6,5,1,2, 3,132,1,5,6,2,0,4,7,3, 7,133,1,5,6,2,0,4,7,3, 6,134,&
  3,0,1,2,7,4,5,6,12,135,3,2,6,7,0,1,5,4, 2,136,4,0,3,7,5,1,2,6, 5,137,&
  7,4,0,3,6,5,1,2, 6,138,2,3,0,1,6,7,4,5,14,139,6,7,3,2,5,4,0,1, 5,140,&
  2,3,0,1,6,7,4,5, 9,141,1,2,3,0,5,6,7,4,11,142,0,0,0,0,0,0,0,0, 0,  0,&
  4,0,3,7,5,1,2,6, 2,144,3,7,4,0,2,6,5,1, 5,145,7,6,5,4,3,2,1,0, 6,146,&
  1,0,4,5,2,3,7,6,11,147,4,0,3,7,5,1,2,6, 6,148,3,7,4,0,2,6,5,1,12,149,&
  1,0,4,5,2,3,7,6,10,150,0,0,0,0,0,0,0,0, 0,  0,0,3,7,4,1,2,6,5, 5,152,&
  4,0,3,7,5,1,2,6, 8,153,0,3,7,4,1,2,6,5,12,154,0,0,0,0,0,0,0,0, 0,  0,&
  0,3,7,4,1,2,6,5,14,156,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,5,1,0,4,6,2,3,7, 3,160,1,2,3,0,5,6,7,4, 7,161,&
  1,0,4,5,2,3,7,6, 6,162,4,5,1,0,7,6,2,3,12,163,3,0,1,2,7,4,5,6, 7,164,&
  0,1,2,3,4,5,6,7,13,165,6,2,1,5,7,3,0,4,12,166,0,0,0,0,0,0,0,0, 0,  0,&
  3,2,6,7,0,1,5,4, 6,168,4,0,3,7,5,1,2,6,12,169,1,2,3,0,5,6,7,4,10,170,&
  0,0,0,0,0,0,0,0, 0,  0,6,7,3,2,5,4,0,1,12,172,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,6,5,4,7,2,1,0,3, 5,176,&
  0,4,5,1,3,7,6,2, 9,177,0,4,5,1,3,7,6,2,14,178,0,0,0,0,0,0,0,0, 0,  0,&
  6,5,4,7,2,1,0,3,12,180,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,5,4,7,6,1,0,3,2,11,184,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  7,3,2,6,4,0,1,5, 2,192,6,5,4,7,2,1,0,3, 6,193,7,3,2,6,4,0,1,5, 6,194,&
  0,3,7,4,1,2,6,5,10,195,3,2,6,7,0,1,5,4, 5,196,3,2,6,7,0,1,5,4,12,197,&
  3,2,6,7,0,1,5,4,14,198,0,0,0,0,0,0,0,0, 0,  0,2,6,7,3,1,5,4,0, 5,200,&
  0,3,7,4,1,2,6,5,11,201,2,6,7,3,1,5,4,0,12,202,0,0,0,0,0,0,0,0, 0,  0,&
  3,2,6,7,0,1,5,4, 8,204,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,5,4,7,6,1,0,3,2, 5,208,3,7,4,0,2,6,5,1,14,209,&
  5,4,7,6,1,0,3,2,12,210,0,0,0,0,0,0,0,0, 0,  0,4,7,6,5,0,3,2,1,11,212,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  6,7,3,2,5,4,0,1, 9,216,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,4,7,6,5,0,3,2,1, 5,224,&
  4,7,6,5,0,3,2,1,12,225,1,5,6,2,0,4,7,3,11,226,0,0,0,0,0,0,0,0, 0,  0,&
  7,6,5,4,3,2,1,0, 9,228,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,2,6,7,3,1,5,4,0,14,232,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  5,4,7,6,1,0,3,2, 8,240,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0&
  /

  INTEGER, TARGET,DIMENSION(0:14,0:12) :: PATHCCLIST
  INTEGER, DIMENSION(0:12,0:14) :: PATHCCLISTT
  DATA ((PATHCCLISTT(I,J),I=0,12),J=0,14) /&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   3, 0, 1, 2,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   6, 0, 1, 2, 2, 3, 0,-1,-1,-1,-1,-1,-1,&
   6, 0, 1, 2, 3, 4, 5,-1,-1,-1,-1,-1,-1,&
   6, 0, 1, 2, 3, 4, 5,-1,-1,-1,-1,-1,-1,&
   9, 0, 1, 2, 2, 3, 4, 0, 2, 4,-1,-1,-1,&
   9, 0, 1, 2, 2, 3, 0, 4, 5, 6,-1,-1,-1,&
   9, 0, 1, 2, 3, 4, 5, 6, 7, 8,-1,-1,-1,&
   6, 0, 1, 2, 2, 3, 0,-1,-1,-1,-1,-1,-1,&
  12, 0, 1, 5, 1, 4, 5, 1, 2, 4, 2, 3, 4,&
  12, 0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7,&
  12, 0, 1, 5, 1, 4, 5, 1, 2, 4, 2, 3, 4,&
  12, 0, 1, 2, 3, 4, 5, 3, 5, 6, 3, 6, 7,&
  12, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,&
  12, 0, 1, 5, 1, 4, 5, 1, 2, 4, 2, 3, 4&
  /

  INTEGER, TARGET,DIMENSION(0:14,0:15) :: PATHCCLIST2
  INTEGER, DIMENSION(0:15,0:14) :: PATHCCLIST2T
  DATA ((PATHCCLIST2T(I,J),I=0,15),J=0,14) /&
    0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
    0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
    0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   12, 0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7,-1,-1,-1,&
    0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
    0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   15, 0, 1, 2, 0, 2, 3, 4, 5, 6, 7, 8, 9, 7, 9,10,&
   15, 0, 1, 2, 3, 4, 5, 3, 5, 7, 3, 7, 8, 5, 6, 7,&
    0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
    0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   12, 0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7,-1,-1,-1,&
    0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   12, 0, 1, 2, 3, 4, 6, 3, 6, 7, 4, 5, 6,-1,-1,-1,&
   12, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,-1,-1,-1,&
    0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1&
   /

  INTEGER, POINTER,DIMENSION(:) :: PATH
  INTEGER, TARGET,DIMENSION(0:14,0:12) :: PATHCCWLIST
  INTEGER, DIMENSION(0:12,0:14) :: PATHCCWLISTT
  DATA ((PATHCCWLISTT(I,J),I=0,12),J=0,14) /&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   3, 0, 2, 1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   6, 0, 2, 1, 0, 3, 2,-1,-1,-1,-1,-1,-1,&
   6, 0, 2, 1, 3, 5, 4,-1,-1,-1,-1,-1,-1,&
   6, 0, 2, 1, 3, 5, 4,-1,-1,-1,-1,-1,-1,&
   9, 0, 2, 1, 2, 4, 3, 0, 4, 2,-1,-1,-1,&
   9, 0, 2, 1, 0, 3, 2, 4, 6, 5,-1,-1,-1,&
   9, 0, 2, 1, 3, 5, 4, 6, 8, 7,-1,-1,-1,&
   6, 0, 2, 1, 0, 3, 2,-1,-1,-1,-1,-1,-1,&
  12, 0, 5, 1, 1, 5, 4, 1, 4, 2, 2, 4, 3,&
  12, 0, 2, 1, 0, 3, 2, 4, 6, 5, 4, 7, 6,&
  12, 0, 5, 1, 1, 5, 4, 1, 4, 2, 2, 4, 3,&
  12, 0, 2, 1, 3, 5, 4, 3, 6, 5, 3, 7, 6,&
  12, 0, 2, 1, 3, 5, 4, 6, 8, 7, 9,11,10,&
  12, 0, 5, 1, 1, 5, 4, 1, 4, 2, 2, 4, 3&
   /

  INTEGER, TARGET,DIMENSION(0:14,0:15) :: PATHCCWLIST2
  INTEGER, DIMENSION(0:15,0:14) :: PATHCCWLIST2T
  DATA ((PATHCCWLIST2T(I,J),I=0,15),J=0,14) /&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
  12, 0, 2, 1, 0, 3, 2, 4, 6, 5, 4, 7, 6,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
  15, 0, 2, 1, 0, 3, 2, 4, 6, 5, 7, 9, 8, 7,10, 9,&
  15, 0, 2, 1, 3, 5, 4, 3, 7, 5, 3, 8, 7, 5, 7, 6,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
  12, 0, 2, 1, 0, 3, 2, 4, 6, 5, 4, 7, 6,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
  12, 0, 2, 1, 3, 6, 4, 3, 7, 6, 4, 6, 5,-1,-1,-1,&
  12, 0, 2, 1, 3, 5, 4, 6, 8, 7, 9,11,10,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1&
  /


  INTEGER, POINTER,DIMENSION(:) :: EDGES
  INTEGER, TARGET,DIMENSION(0:14,0:12) :: EDGELIST
  INTEGER, DIMENSION(0:12,0:14) :: EDGELISTT
  DATA ((EDGELISTT(I,J),I=0,12),J=0,14) /&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   3, 0, 4, 3,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   4, 0, 4, 7, 2,-1,-1,-1,-1,-1,-1,-1,-1,&
   6, 0, 4, 3, 7,11,10,-1,-1,-1,-1,-1,-1,&
   6, 0, 4, 3, 6,10, 9,-1,-1,-1,-1,-1,-1,&
   5, 0, 3, 7, 6, 5,-1,-1,-1,-1,-1,-1,-1,&
   7, 0, 4, 7, 2, 6,10, 9,-1,-1,-1,-1,-1,&
   9, 4, 8,11, 2, 3, 7, 6,10, 9,-1,-1,-1,&
   4, 4, 7, 6, 5,-1,-1,-1,-1,-1,-1,-1,-1,&
   6, 2, 6, 9, 8, 4, 3,-1,-1,-1,-1,-1,-1,&
   8, 0, 8,11, 3,10, 9, 1, 2,-1,-1,-1,-1,&
   6, 4, 3, 2,10, 9, 5,-1,-1,-1,-1,-1,-1,&
   8, 4, 8,11, 0, 3, 7, 6, 5,-1,-1,-1,-1,&
  12, 0, 4, 3, 7,11,10, 2, 6, 1, 8, 5, 9,&
   6, 3, 7, 6, 9, 8, 0,-1,-1,-1,-1,-1,-1&
  /

  INTEGER, TARGET,DIMENSION(0:14,0:15) :: EDGELIST2
  INTEGER, DIMENSION(0:15,0:14) :: EDGELIST2T
  DATA ((EDGELIST2T(I,J),I=0,15),J=0,14) /&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   8, 3, 0,10, 7, 0, 4,11,10,-1,-1,-1,-1,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
  11, 7,10, 9, 4, 0, 4, 9, 0, 9, 6, 2,-1,-1,-1,-1,&
   9, 7,10,11, 3, 4, 8, 9, 6, 2,-1,-1,-1,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   8, 0, 8, 9, 1, 3, 2,10,11,-1,-1,-1,-1,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   8, 0, 3, 4, 8,11, 7, 6, 5,-1,-1,-1,-1,-1,-1,-1,&
  12, 4,11, 8, 0, 5, 1, 7, 3, 2, 9,10, 6,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1&
  /

  REAL(FB) :: VMIN, VMAX
  INTEGER :: CASENUM, BIGGER, SIGN, N
  INTEGER, DIMENSION(0:7) :: PRODS=(/1,2,4,8,16,32,64,128/);
  REAL(FB), DIMENSION(0:7) :: XXVAL,YYVAL,ZZVAL
  INTEGER, DIMENSION(0:3) :: IXMIN=(/0,1,4,5/), IXMAX=(/2,3,6,7/)
  INTEGER, DIMENSION(0:3) :: IYMIN=(/0,3,4,7/), IYMAX=(/1,2,5,6/)
  INTEGER, DIMENSION(0:3) :: IZMIN=(/0,1,2,3/), IZMAX=(/4,5,6,7/)
  INTEGER :: TYPE2,THISTYPE2
  INTEGER :: NEDGES,NPATH
  INTEGER :: OUTOFBOUNDS, EDGE, V1, V2
  REAL(FB) :: VAL1, VAL2, DENOM, FACTOR
  REAL(FB) :: XX, YY, ZZ

  EDGE2VERTEX=TRANSPOSE(EDGE2VERTEXTT)
  CASES=TRANSPOSE(CASEST)
  PATHCCLIST=TRANSPOSE(PATHCCLISTT)
  PATHCCLIST2=TRANSPOSE(PATHCCLIST2T)
  PATHCCWLIST=TRANSPOSE(PATHCCWLISTT)
  PATHCCWLIST2=TRANSPOSE(PATHCCWLIST2T)
  EDGELIST=TRANSPOSE(EDGELISTT)
  EDGELIST2=TRANSPOSE(EDGELIST2T)

  VMIN=MIN(VALS(0),VALS(1),VALS(2),VALS(3),VALS(4),VALS(5),VALS(6),VALS(7))
  VMAX=MAX(VALS(0),VALS(1),VALS(2),VALS(3),VALS(4),VALS(5),VALS(6),VALS(7))

  NXYZV=0
  NTRIS=0

  IF (VMIN>LEVEL.OR.VMAX<LEVEL) RETURN

  CASENUM=0
  BIGGER=0
  SIGN=1

  DO N = 0, 7
    IF (VALS(N)>LEVEL) THEN
      BIGGER=BIGGER+1
      CASENUM = CASENUM + PRODS(N);
    ENDIF
  END DO

! THERE ARE MORE NODES GREATER THAN THE ISO-SURFACE LEVEL THAN BELOW, SO
!   SOLVE THE COMPLEMENTARY PROBLEM

  IF (BIGGER > 4) THEN
    SIGN=-1
    CASENUM=0
    DO N=0, 7
      IF (VALS(N)<LEVEL) THEN
        CASENUM = CASENUM + PRODS(N)
      ENDIF
    END DO
  ENDIF

! STUFF MIN AND MAX GRID DATA INTO A MORE CONVENIENT FORM
!  ASSUMING THE FOLLOWING GRID NUMBERING SCHEME

!       5-------6
!     / |      /|
!   /   |     / |
!  4 -------7   |
!  |    |   |   |
!  Z    1---|---2
!  |  Y     |  /
!  |/       |/
!  0--X-----3


  DO N=0, 3
    XXVAL(IXMIN(N)) = X(0);
    XXVAL(IXMAX(N)) = X(1);
    YYVAL(IYMIN(N)) = Y(0);
    YYVAL(IYMAX(N)) = Y(1);
    ZZVAL(IZMIN(N)) = Z(0);
    ZZVAL(IZMAX(N)) = Z(1);
  END DO

  IF (CASENUM<=0.OR.CASENUM>=255) THEN ! NO ISO-SURFACE
    NTRIS=0
    RETURN
  ENDIF

  CASE2(0:9) => CASES(CASENUM,0:9)
  TYPE2 = CASE2(8);
  IF (TYPE2==0) THEN
    NTRIS=0
    RETURN
  ENDIF

  IF (COMPCASE(TYPE2) == -1) THEN
    THISTYPE2=SIGN
  ELSE
    THISTYPE2=1
  ENDIF

  IF (THISTYPE2 /= -1) THEN
    !EDGES = &(EDGELIST[TYPE][1]);
    EDGES(-1:11) => EDGELIST(TYPE2,0:12)
    IF (SIGN >=0) THEN
     ! PATH = &(PATHCCLIST[TYPE][1])   !  CONSTRUCT TRIANGLES CLOCK WISE
      PATH(-1:11) => PATHCCLIST(TYPE2,0:12)
    ELSE
     ! PATH = &(PATHCCWLIST[TYPE][1])  !  CONSTRUCT TRIANGLES COUNTER CLOCKWISE
      PATH(-1:11) => PATHCCWLIST(TYPE2,0:12)
    ENDIF
  ELSE
    !EDGES = &(EDGELIST2[TYPE][1]);
    EDGES(-1:11) => EDGELIST2(TYPE2,0:12)
    IF (SIGN > 0) THEN
     ! PATH = &(PATHCCLIST2[TYPE][1])  !  CONSTRUCT TRIANGLES CLOCK WISE
      PATH(-1:14) => PATHCCLIST2(TYPE2,0:15)
    ELSE
     ! PATH = &(PATHCCWLIST2[TYPE][1]) !  CONSTRUCT TRIANGLES COUNTER CLOCKWISE
      PATH(-1:14) => PATHCCWLIST2(TYPE2,0:15)
    ENDIF
  ENDIF
  NPATH = PATH(-1);
  NEDGES = EDGES(-1);

  OUTOFBOUNDS=0
  DO N=0,NEDGES-1
    EDGE = EDGES(N)
    V1 = CASE2(EDGE2VERTEX(EDGE,0));
    V2 = CASE2(EDGE2VERTEX(EDGE,1));
    VAL1 = VALS(V1)-LEVEL
    VAL2 = VALS(V2)-LEVEL
    DENOM = VAL2 - VAL1
    FACTOR = 0.5_FB
    IF (DENOM /= 0.0_FB)FACTOR = -VAL1/DENOM
    XX = FMIX(FACTOR,XXVAL(V1),XXVAL(V2));
    YY = FMIX(FACTOR,YYVAL(V1),YYVAL(V2));
    ZZ = FMIX(FACTOR,ZZVAL(V1),ZZVAL(V2));
    XYZV_LOCAL(3*N) = XX;
    XYZV_LOCAL(3*N+1) = YY;
    XYZV_LOCAL(3*N+2) = ZZ;

  END DO

! COPY COORDINATES TO OUTPUT ARRAY

  NXYZV = NEDGES;
  NTRIS = NPATH/3;
  IF (NPATH > 0) THEN
    TRIS(0:NPATH-1) = PATH(0:NPATH-1)
  ENDIF
END SUBROUTINE GETISOBOX

! ----------------------- UPDATEISOSURFACE -------------------------

!> \brief Routine to add the isosurface from a single grid cell to the global isosurface. 

SUBROUTINE UPDATEISOSURFACE(XYZVERTS_BOX, NXYZVERTS_BOX, TRIS_BOX, NTRIS_BOX,  &
                            XYZVERTS, NXYZVERTS, NXYZVERTS_MAX, TRIANGLES, NTRIANGLES, NTRIANGLES_MAX)
  REAL(FB), INTENT(IN), DIMENSION(0:35) :: XYZVERTS_BOX
  INTEGER, INTENT(IN) :: NXYZVERTS_BOX, NTRIS_BOX
  INTEGER, INTENT(IN), DIMENSION(0:14) :: TRIS_BOX
  REAL(FB), DIMENSION(:), ALLOCATABLE :: XYZVERTS
  INTEGER, INTENT(INOUT) :: NXYZVERTS, NXYZVERTS_MAX, NTRIANGLES, NTRIANGLES_MAX
  INTEGER, DIMENSION(:), ALLOCATABLE :: TRIANGLES

  INTEGER :: NXYZVERTS_NEW, NTRIANGLES_NEW

  NXYZVERTS_NEW = NXYZVERTS + NXYZVERTS_BOX
  NTRIANGLES_NEW = NTRIANGLES + NTRIS_BOX
  IF (1+NXYZVERTS_NEW > NXYZVERTS_MAX) THEN
    NXYZVERTS_MAX = 1+NXYZVERTS_NEW+1000
    CALL REALLOCATE_F(XYZVERTS,3*NXYZVERTS,3*NXYZVERTS_MAX)
  ENDIF
  IF (1+NTRIANGLES_NEW > NTRIANGLES_MAX) THEN
    NTRIANGLES_MAX = 1+NTRIANGLES_NEW+1000
    CALL REALLOCATE_I(TRIANGLES,3*NTRIANGLES,3*NTRIANGLES_MAX)
  ENDIF
  XYZVERTS(1+3*NXYZVERTS:3*NXYZVERTS_NEW) = XYZVERTS_BOX(0:3*NXYZVERTS_BOX-1)
  TRIANGLES(1+3*NTRIANGLES:3*NTRIANGLES_NEW) = NXYZVERTS+TRIS_BOX(0:3*NTRIS_BOX-1)
  NXYZVERTS = NXYZVERTS_NEW
  NTRIANGLES = NTRIANGLES_NEW
END SUBROUTINE UPDATEISOSURFACE

! ----------------------- REALLOCATE_I -------------------------

!> \brief Routine to to change the size (usually increase) of an allocatable integer array. 

SUBROUTINE REALLOCATE_I(VALS,OLDSIZE,NEWSIZE)

  INTEGER, DIMENSION(:), ALLOCATABLE :: VALS
  INTEGER, INTENT(IN) :: OLDSIZE, NEWSIZE
  INTEGER, DIMENSION(:), ALLOCATABLE :: VALS_TEMP

  IF (OLDSIZE > 0) THEN
    ALLOCATE(VALS_TEMP(OLDSIZE))
    VALS_TEMP(1:OLDSIZE) = VALS(1:OLDSIZE)
    DEALLOCATE(VALS)
  ENDIF
  ALLOCATE(VALS(NEWSIZE))
  IF (OLDSIZE > 0) THEN
    VALS(1:OLDSIZE)=VALS_TEMP(1:OLDSIZE)
    DEALLOCATE(VALS_TEMP)
  ENDIF
END SUBROUTINE REALLOCATE_I

! ----------------------- REALLOCATE_F -------------------------

!> \brief Routine to change the size (usually increase) of an allocatable floating point array. 

SUBROUTINE REALLOCATE_F(VALS,OLDSIZE,NEWSIZE)

  REAL(FB), INTENT(INOUT), DIMENSION(:), ALLOCATABLE :: VALS
  INTEGER, INTENT(IN) :: OLDSIZE, NEWSIZE
  REAL(FB), DIMENSION(:), ALLOCATABLE :: VALS_TEMP

  IF (OLDSIZE > 0) THEN
    ALLOCATE(VALS_TEMP(OLDSIZE))
    VALS_TEMP(1:OLDSIZE) = VALS(1:OLDSIZE)
    DEALLOCATE(VALS)
  ENDIF
  ALLOCATE(VALS(NEWSIZE))
  IF (OLDSIZE > 0) THEN
    VALS(1:OLDSIZE)=VALS_TEMP(1:OLDSIZE)
    DEALLOCATE(VALS_TEMP)
  ENDIF
END SUBROUTINE REALLOCATE_F

! ----------------------- FMIX -------------------------

!> \brief Routine to compute the linear combination of two values. 

REAL(FB) FUNCTION FMIX(F,A,B)
  REAL(FB), INTENT(IN) :: F, A, B
  FMIX = (1.0_FB-F)*A + F*B
END FUNCTION FMIX


!> \brief Routine to generate a run length encoded version of a slice file. 

SUBROUTINE SLICE_TO_RLEFILE(LU_SLICE_RLE, TIME, NX, NY, NZ, VALS, RLE_MIN, RLE_MAX)
  INTEGER, INTENT(IN) :: NX, NY, NZ, LU_SLICE_RLE
  REAL(FB), INTENT(IN) :: TIME, RLE_MIN, RLE_MAX
  REAL(FB), INTENT(IN), DIMENSION(NX*NY*NZ) :: VALS

  CHARACTER(LEN=1), DIMENSION(:), ALLOCATABLE :: BUFFER_IN, BUFFER_OUT
  INTEGER :: I, NCHARS_IN, NCHARS_OUT, NVALS, IVAL

  NVALS=NX*NY*NZ
  NCHARS_IN=NVALS

  IF (NVALS < 1) RETURN

  ALLOCATE(BUFFER_IN(NVALS))
  ALLOCATE(BUFFER_OUT(NVALS))

  ! compute bounds if bounds were not specified on the &SLCF line

  IF (RLE_MAX.GT.RLE_MIN) THEN
     DO I = 1, NVALS
        IVAL = INT(254._FB*(VALS(I)-RLE_MIN)/(RLE_MAX-RLE_MIN))
        IVAL = MIN(254,IVAL)
        IVAL = MAX(0, IVAL)
        BUFFER_IN(I) = CHAR(IVAL)
     END DO
  ELSE
     DO I = 1, NVALS
        BUFFER_IN(I) = CHAR(0)
     END DO
  ENDIF
  CALL RLE(BUFFER_IN,NCHARS_IN,BUFFER_OUT,NCHARS_OUT)

  WRITE(LU_SLICE_RLE)TIME
  WRITE(LU_SLICE_RLE)NCHARS_IN,NCHARS_OUT
  IF (NCHARS_OUT > 0)WRITE(LU_SLICE_RLE)(BUFFER_OUT(I),I=1,NCHARS_OUT)

  DEALLOCATE(BUFFER_IN)
  DEALLOCATE(BUFFER_OUT)
 END SUBROUTINE SLICE_TO_RLEFILE


!> \brief Routine to generate SMOKE3D compressed data to send to Smokeview

SUBROUTINE SMOKE3D_TO_FILE(NM,TIME,DX,SMOKE3D_INDEX,VALS,NX,NY,NZ,SMOKE3D_16_FLAG)

USE OUTPUT_DATA, ONLY: SMOKE3D_TYPE,SMOKE3D_FILE,N_SMOKE3D
USE GLOBAL_CONSTANTS, ONLY: TMPA,TMPM,LU_SMOKE3D,FN_SMOKE3D,TEMP_MAX_SMV,HRRPUV_MAX_SMV
INTEGER, INTENT(IN) :: NX,NY,NZ,NM,SMOKE3D_INDEX
LOGICAL, INTENT(IN) :: SMOKE3D_16_FLAG
REAL(FB), INTENT(IN) :: TIME, DX
REAL(FB), INTENT(IN), DIMENSION(NX*NY*NZ) :: VALS
CHARACTER(LEN=1), DIMENSION(:), ALLOCATABLE :: BUFFER_IN, BUFFER_OUT
CHARACTER(LEN=1), DIMENSION(:), ALLOCATABLE, TARGET :: BUFFER16_IN
REAL(FB) :: FACTOR,TEMP_MIN,VAL_FDS,VAL_SMV,MAX_VAL
INTEGER :: I,NCHARS_OUT,NVALS,NCHARS_IN
INTEGER :: VAL16, FACTOR16, NVALS16_OUT
INTEGER :: VAL_LOW, VAL_HIGH
TYPE(SMOKE3D_TYPE), POINTER :: S3
REAL(FB) :: SMOKE3D_16_VALMIN, SMOKE3D_16_VALMAX

S3 => SMOKE3D_FILE(SMOKE3D_INDEX)

NVALS = NX*NY*NZ
NCHARS_IN = NVALS

ALLOCATE(BUFFER_IN(NVALS))
ALLOCATE(BUFFER_OUT(NVALS))

MAX_VAL=0.0_FB

IF (S3%DISPLAY_TYPE=='GAS') THEN

   FACTOR=-REAL(S3%MASS_EXTINCTION_COEFFICIENT,FB)*DX
   DO I=1,NVALS
      VAL_FDS = MAX(0.0_FB,VALS(I))
      VAL_SMV = 254*(1.0_FB-EXP(FACTOR*VAL_FDS))
      BUFFER_IN(I) = CHAR(NINT(VAL_SMV))
      MAX_VAL = MAX(VAL_SMV,MAX_VAL)  ! If MAX_VAL=0, soot in mesh is completely transparent
   ENDDO

ELSEIF (S3%DISPLAY_TYPE=='FIRE') THEN

   DO I=1,NVALS
      VAL_FDS = MIN(HRRPUV_MAX_SMV,MAX(0._FB,VALS(I)))
      VAL_SMV = 254*(VAL_FDS/HRRPUV_MAX_SMV)
      BUFFER_IN(I) = CHAR(INT(VAL_SMV))
      MAX_VAL = MAX(VAL_FDS,MAX_VAL)
   ENDDO

ELSEIF (S3%DISPLAY_TYPE=='TEMPERATURE') THEN

   TEMP_MIN = REAL(TMPA-TMPM,FB)
   DO I=1,NVALS
      VAL_FDS = MIN(TEMP_MAX_SMV,MAX(TEMP_MIN,VALS(I)))
      VAL_SMV = 254*((VAL_FDS-TEMP_MIN)/(TEMP_MAX_SMV-TEMP_MIN))
      BUFFER_IN(I) = CHAR(INT(VAL_SMV))
   ENDDO

ELSE

    NCHARS_OUT=0

ENDIF

! Pack the values into a compressed buffer

CALL RLE(BUFFER_IN,NCHARS_IN,BUFFER_OUT,NCHARS_OUT)

! Write size information to a text file

IF (.NOT.SMOKE3D_16_FLAG) THEN ! write out an extra column below if SMOKE3D_16_FLAG is true
   OPEN(LU_SMOKE3D(SMOKE3D_INDEX+N_SMOKE3D,NM),FILE=FN_SMOKE3D(SMOKE3D_INDEX+N_SMOKE3D,NM),&
        FORM='FORMATTED',STATUS='OLD',POSITION='APPEND')
   WRITE(LU_SMOKE3D(SMOKE3D_INDEX+N_SMOKE3D,NM),*) TIME,NCHARS_IN,NCHARS_OUT,MAX_VAL
   CLOSE(LU_SMOKE3D(SMOKE3D_INDEX+N_SMOKE3D,NM))
ENDIF

! Write data

OPEN(LU_SMOKE3D(SMOKE3D_INDEX,NM),FILE=FN_SMOKE3D(SMOKE3D_INDEX,NM),FORM='UNFORMATTED',STATUS='OLD',POSITION='APPEND')
WRITE(LU_SMOKE3D(SMOKE3D_INDEX,NM)) TIME
WRITE(LU_SMOKE3D(SMOKE3D_INDEX,NM)) NCHARS_IN,NCHARS_OUT
WRITE(LU_SMOKE3D(SMOKE3D_INDEX,NM)) (BUFFER_OUT(I),I=1,NCHARS_OUT)
CLOSE(LU_SMOKE3D(SMOKE3D_INDEX,NM))
! write out data as 2 byte integers

IF (SMOKE3D_16_FLAG) THEN
   NVALS16_OUT = NVALS   ! after compression is added, NVALS16_OUT will be smaller than NVALS
   ALLOCATE(BUFFER16_IN(2*NVALS))
   SMOKE3D_16_VALMIN = VALS(1)
   SMOKE3D_16_VALMAX = SMOKE3D_16_VALMIN
   DO I=2,NVALS
      SMOKE3D_16_VALMIN = MIN(SMOKE3D_16_VALMIN,VALS(I))
      SMOKE3D_16_VALMAX = MAX(SMOKE3D_16_VALMAX,VALS(I))
   ENDDO
   IF (SMOKE3D_16_VALMIN == SMOKE3D_16_VALMAX) THEN
      SMOKE3D_16_VALMAX = SMOKE3D_16_VALMIN + 1.0_FB
   ENDIF
   FACTOR16 = 2**16 - 1
   DO I=1,NVALS
      VAL16 = INT(FACTOR16*(VALS(I)-SMOKE3D_16_VALMIN)/(SMOKE3D_16_VALMAX-SMOKE3D_16_VALMIN))
      VAL16 = MIN(MAX(0, VAL16), FACTOR16)
      VAL_LOW = MOD(VAL16, 256)
      VAL_HIGH = VAL16/256
      BUFFER16_IN(2*I-1) = CHAR(VAL_HIGH)  
      BUFFER16_IN(2*i)   = CHAR(VAL_LOW)
   ENDDO

   OPEN(LU_SMOKE3D(SMOKE3D_INDEX+N_SMOKE3D,NM),FILE=FN_SMOKE3D(SMOKE3D_INDEX+N_SMOKE3D,NM),&
        FORM='FORMATTED',STATUS='OLD',POSITION='APPEND')
   WRITE(LU_SMOKE3D(SMOKE3D_INDEX+N_SMOKE3D,NM),*) TIME,NCHARS_IN,NCHARS_OUT,MAX_VAL,NVALS16_OUT
   CLOSE(LU_SMOKE3D(SMOKE3D_INDEX+N_SMOKE3D,NM))

   OPEN(LU_SMOKE3D(SMOKE3D_INDEX+2*N_SMOKE3D,NM),FILE=FN_SMOKE3D(SMOKE3D_INDEX+2*N_SMOKE3D,NM),FORM='UNFORMATTED',&
        STATUS='OLD',POSITION='APPEND')
   WRITE(LU_SMOKE3D(SMOKE3D_INDEX + 2*N_SMOKE3D,NM)) TIME
   WRITE(LU_SMOKE3D(SMOKE3D_INDEX + 2*N_SMOKE3D,NM)) NVALS,NVALS16_OUT,SMOKE3D_16_VALMIN,SMOKE3D_16_VALMAX
   ! output (2**16 - 1)(val-valmin)/(valmax-valmin)
   WRITE(LU_SMOKE3D(SMOKE3D_INDEX + 2*N_SMOKE3D,NM)) (BUFFER16_IN(I),I=1,2*NVALS)
   CLOSE(LU_SMOKE3D(SMOKE3D_INDEX + 2*N_SMOKE3D,NM))
   DEALLOCATE(BUFFER16_IN)
ENDIF

DEALLOCATE(BUFFER_IN)
DEALLOCATE(BUFFER_OUT)

END SUBROUTINE SMOKE3D_TO_FILE


!> \brief Routine to compress 3D smoke data using run length encoding (RLE).

SUBROUTINE RLE(BUFFER_IN, NCHARS_IN, BUFFER_OUT, NCHARS_OUT)

  INTEGER, INTENT(IN) :: NCHARS_IN
  CHARACTER(LEN=1), INTENT(IN), DIMENSION(NCHARS_IN) :: BUFFER_IN
  CHARACTER(LEN=1), DIMENSION(:) :: BUFFER_OUT
  INTEGER, INTENT(OUT) :: NCHARS_OUT

  CHARACTER(LEN=1) :: MARK=CHAR(255),THISCHAR,LASTCHAR
  INTEGER :: N,N2,NREPEATS

   NREPEATS=1
   LASTCHAR=MARK
   N2=1
   DO N=1,NCHARS_IN
     THISCHAR=BUFFER_IN(N)
     IF (THISCHAR == LASTCHAR) THEN
       NREPEATS=NREPEATS+1
     ELSE
       NREPEATS=1
     ENDIF
     IF (NREPEATS >=1.AND.NREPEATS <= 3) THEN
       BUFFER_OUT(N2)=THISCHAR
       LASTCHAR=THISCHAR
     ELSE
       IF (NREPEATS == 4) THEN
         N2=N2-3
         BUFFER_OUT(N2)=MARK
         BUFFER_OUT(N2+1)=THISCHAR
         N2=N2+2
       ELSE
         N2=N2-1
       ENDIF
       BUFFER_OUT(N2)=CHAR(NREPEATS)
       IF (NREPEATS == 254) THEN
         NREPEATS=1
         LASTCHAR=MARK
       ENDIF
     ENDIF
     N2=N2+1
   END DO
   NCHARS_OUT=N2-1
END SUBROUTINE RLE

END MODULE ISOSMOKE
