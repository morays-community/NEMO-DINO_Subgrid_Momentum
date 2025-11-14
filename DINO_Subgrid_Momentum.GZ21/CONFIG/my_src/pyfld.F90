MODULE pyfld
   !!======================================================================
   !!                       ***  MODULE pyfld  ***
   !! Python module :   variables defined in core memory
   !!======================================================================
   !! History :  4.2  ! 2025-11  (A. Barge)  Original code
   !!----------------------------------------------------------------------

   !!----------------------------------------------------------------------
   !!   pyfld_alloc : allocation of fields arrays for Python coupling module (pycpl)
   !!----------------------------------------------------------------------
   !!=====================================================
   USE oce            ! ocean fields
   USE dom_oce        ! ocean metrics fields
   USE par_oce        ! ocean parameters
   USE lib_mpp        ! MPP library
   USE pycpl          ! Python coupling module
   USE iom

   IMPLICIT NONE
   PRIVATE

   PUBLIC   pyfld_alloc   ! routine called in pycpl.F90
   PUBLIC   pyfld_dealloc ! routine called in pycpl.F90

   !!----------------------------------------------------------------------
   !!                    2D Python coupling Module fields
   !!----------------------------------------------------------------------
   !REAL(wp), PUBLIC, ALLOCATABLE, SAVE, DIMENSION(:,:)  :: tmp_fld_2D    !: dummy field to store 2D fields

   !!----------------------------------------------------------------------
   !!                    3D Python coupling Module fields
   !!----------------------------------------------------------------------
   REAL(wp), PUBLIC, SAVE, DIMENSION(jpi,jpj,jpk)  :: ext_uf, ext_vf  !: dummy field to store 3D fields

CONTAINS

   SUBROUTINE inputs_gz21( kt )
      !!----------------------------------------------------------------------
      !!             ***  ROUTINE inputs_gz21  ***
      !!
      !! ** Purpose :   send inputs fileds for gz21 model
      !!
      !! ** Method  :   *
      !!                *
      !!----------------------------------------------------------------------
      INTEGER, INTENT(in) ::   kt            ! ocean time step
      !!----------------------------------------------------------------------
      !
      ! send velocities and masks
      CALL send_to_python( 'u', uu(:,:,:,Nbb), kt )    ! Send fields to Python models
      CALL send_to_python( 'v', vv(:,:,:,Nbb), kt )    ! Send fields to Python models
      CALL send_to_python( 'mask_u', umask, kt )    ! Send fields to Python models
      CALL send_to_python( 'mask_v', vmask, kt )    ! Send fields to Python models
      !
   END SUBROUTINE inputs_gz21


   SUBROUTINE update_from_gz21( kt )
      !!----------------------------------------------------------------------
      !!             ***  ROUTINE update_from_gz21  ***
      !!
      !! ** Purpose :   update the ocean data with the coupled GZ21 models
      !!
      !! ** Method  :   *
      !!                *
      !!----------------------------------------------------------------------
      INTEGER, INTENT(in) ::   kt            ! ocean time step
      !!----------------------------------------------------------------------
      !
      ! Proceed receptions
      CALL receive_from_python( 'u_f', ext_uf, kstp )  ! Add forcing from Python models ==> RHS
      CALL receive_from_python( 'v_f', ext_vf, kstp )  ! Add forcing from Python models ==> RHS
      !
      ! update ocean
      uu(:,:,:,Nrhs) = uu(:,:,:,Nrhs) + ext_uf(:,:,:)
      vv(:,:,:,Nrhs) = vv(:,:,:,Nrhs) + ext_vf(:,:,:)
      !
      ! Outputs results
      CALL iom_put( 'ext_uf', ext_uf(:,:,1) )
      CALL iom_put( 'ext_vf', ext_vf(:,:,1) )
     !
   END SUBROUTINE  update_from_gz21
  

END MODULE pyfld
