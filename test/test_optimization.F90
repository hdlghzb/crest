module test_optimization
  use testdrive,only:new_unittest,unittest_type,error_type,check,test_failed
  use crest_parameters
  use crest_calculator
  use crest_data,only:refine
  use strucrd
  use crest_testmol
  use optimize_module
  implicit none
  private

  public :: collect_optimization

  real(wp),parameter :: thr = 5e+6_wp*epsilon(1.0_wp)
  real(wp),parameter :: thr2 = 10*sqrt(epsilon(1.0_wp))

!========================================================================================!
!========================================================================================!
contains  !> Unit tests for using geometry optimization routines in CREST
!========================================================================================!
!========================================================================================!

!> Collect all exported unit tests
  subroutine collect_optimization(testsuite)
    !> Collection of tests
    type(unittest_type),allocatable,intent(out) :: testsuite(:)

!&<
    testsuite = [ &
#ifdef WITH_GFNFF
    new_unittest("Compiled gfnff subproject     ",test_compiled_gfnff), &
    new_unittest("optimization (ANCOPT)         ",test_ancopt), &
    new_unittest("optimization (ANCOPT,sspevx)  ",test_ancoptsmall), &
    new_unittest("optimization (grad. descent)  ",test_gradientdescent), &
    new_unittest("optimization (RFO)            ",test_rfo), &
    new_unittest("hybrid optimization components ",test_hybrid_components) &
#else
    new_unittest("Compiled gfnff subproject",test_compiled_gfnff,should_fail=.true.) &
#endif
    ]
!&>
  end subroutine collect_optimization

  subroutine test_compiled_gfnff(error)
    type(error_type),allocatable,intent(out) :: error
#ifndef WITH_GFNFF
    write(*,'("       ...")') 'gfnff not compiled, expecting fail.'
    allocate (error)
#endif
  end subroutine test_compiled_gfnff

!========================================================================================!

  subroutine test_ancopt(error)
    type(error_type),allocatable,intent(out) :: error
    type(calcdata) :: calc
    type(calculation_settings) :: sett
    type(coord) :: mol,molnew
    real(wp) :: energy
    real(wp),allocatable :: grad(:,:)
    integer :: io
    logical :: wr,pr
!&<
    real(wp),parameter :: e_ref = -4.677661756_wp
!&>

    !> setup
    call sett%create('gfnff')
    call calc%add(sett)
    call get_testmol('caffeine',mol)
    allocate (grad(3,mol%nat))

    !> calculation
    wr = .false.
    pr = .false.
    call optimize_geometry(mol,molnew,calc,energy,grad,pr,wr,io)
    !write(*,'(F25.15)') energy
    !write(*,'(3(F20.15,"_wp,")," &")') grad
    call check(error,io,0)
    if (allocated(error)) return

    call check(error,energy,e_ref,thr=1e-6_wp)
    if (allocated(error)) return

    deallocate (grad)
  end subroutine test_ancopt

!========================================================================================!

  subroutine test_ancoptsmall(error)
!*****************************************************
!* Test ANCOPT with a small molecule to trigger exact
!* Hessian eigenvalue calculation via LAPACK's sspevx
!*****************************************************
    type(error_type),allocatable,intent(out) :: error
    type(calcdata) :: calc
    type(calculation_settings) :: sett
    type(coord) :: mol,molnew
    real(wp) :: energy
    real(wp),allocatable :: grad(:,:)
    integer :: io
    logical :: wr,pr
!&<
    real(wp),parameter :: e_ref = -0.630873310757319_wp
!&>

    !> setup
    call sett%create('gfnff')
    call calc%add(sett)
    call get_testmol('methane',mol)
    molnew = mol
    allocate (grad(3,mol%nat))

    !> calculation
    wr = .false.
    pr = .false.
    call optimize_geometry(mol,molnew,calc,energy,grad,pr,wr,io)
    !write(*,'(F25.15)') energy
    !write(*,'(3(F20.15,"_wp,")," &")') grad
    call check(error,io,0)
    if (allocated(error)) return

    call check(error,energy,e_ref,thr=1e-6_wp)
    if (allocated(error)) return

    deallocate (grad)
  end subroutine test_ancoptsmall


!========================================================================================!
  subroutine test_gradientdescent(error)
    type(error_type),allocatable,intent(out) :: error
    type(calcdata) :: calc
    type(calculation_settings) :: sett
    type(coord) :: mol,molnew
    real(wp) :: energy
    real(wp),allocatable :: grad(:,:)
    integer :: io
    logical :: wr,pr
!&<
    real(wp),parameter :: e_ref = -4.677587929227879_wp
!&>

    !> setup
    call sett%create('gfnff')
    call calc%add(sett)
    calc%opt_engine = -1
    call get_testmol('caffeine',mol)
    allocate (grad(3,mol%nat))

    !> calculation
    wr = .false.
    pr = .false.
    call optimize_geometry(mol,molnew,calc,energy,grad,pr,wr,io)
    !write(*,'(F25.15)') energy
    !write(*,'(3(F20.15,"_wp,")," &")') grad
    call check(error,io,0)
    if (allocated(error)) return

    call check(error,energy,e_ref,thr=1e-6_wp)
    if (allocated(error)) return

    deallocate (grad)
  end subroutine test_gradientdescent

!========================================================================================!
  subroutine test_rfo(error)
    type(error_type),allocatable,intent(out) :: error
    type(calcdata) :: calc
    type(calculation_settings) :: sett
    type(coord) :: mol,molnew
    real(wp) :: energy
    real(wp),allocatable :: grad(:,:)
    integer :: io
    logical :: wr,pr
!&<
    real(wp),parameter :: e_ref = -4.677662006957390_wp
!&>

    !> setup
    call sett%create('gfnff')
    call calc%add(sett)
    calc%opt_engine = 2
    call get_testmol('caffeine',mol)
    allocate (grad(3,mol%nat))

    !> calculation
    wr = .false.
    pr = .false.
    call optimize_geometry(mol,molnew,calc,energy,grad,pr,wr,io)
    !write(*,'(F25.15)') energy
    !write(*,'(3(F20.15,"_wp,")," &")') grad
    call check(error,io,0)
    if (allocated(error)) return

    call check(error,energy,e_ref,thr=1e-6_wp)
    if (allocated(error)) return

    deallocate (grad)
  end subroutine test_rfo

!========================================================================================!

  subroutine test_hybrid_components(error)
    type(error_type),allocatable,intent(out) :: error
    type(calcdata) :: hybrid,reference
    type(calculation_settings) :: workhorse,quality,reference_settings
    type(coord) :: mol,molnew,reference_mol
    real(wp) :: energy,reference_energy
    real(wp),allocatable :: grad(:,:),reference_grad(:,:)
    integer :: io
    logical :: wr,pr

    call workhorse%create('gfnff')
    workhorse%refine_lvl = refine%non
    call workhorse%autocomplete(1)
    call hybrid%add(workhorse)
    call quality%create('gfn2')
    quality%refine_lvl = refine%post_opt
    call quality%autocomplete(2)
    call hybrid%add(quality)
    hybrid%refine_stage = refine%post_opt

    call get_testmol('methane',mol)
    allocate (grad(3,mol%nat),source=0.0_wp)
    wr = .false.
    pr = .false.
    call optimize_geometry(mol,molnew,hybrid,energy,grad,pr,wr,io)
    call check(error,io,0)
    if (allocated(error)) return
    if (.not.molnew%energy_components_valid) then
      call test_failed(error,'hybrid quality optimization lost energy components')
      return
    end if
    call check(error,molnew%energy_total,energy,thr=1.0e-10_wp)
    if (allocated(error)) return

    call reference_settings%create('gfn2')
    call reference%add(reference_settings)
    reference_mol = molnew
    allocate (reference_grad(3,reference_mol%nat),source=0.0_wp)
    call engrad(reference_mol,reference,reference_energy,reference_grad,io)
    call check(error,io,0)
    if (allocated(error)) return
    call check(error,molnew%energy_raw,reference_energy,thr=1.0e-10_wp)

    deallocate (grad,reference_grad)
  end subroutine test_hybrid_components

!========================================================================================!
!========================================================================================!
end module test_optimization
