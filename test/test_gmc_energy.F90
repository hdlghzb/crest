module test_gmc_energy
  use testdrive,only:new_unittest,unittest_type,error_type,check,test_failed
  use crest_parameters
  use crest_calculator
  use strucrd
  use crest_testmol,only:get_testmol
  implicit none
  private

  public :: collect_gmc_energy

  real(wp),parameter :: tol = 1.0e-10_wp

contains

  subroutine collect_gmc_energy(testsuite)
    type(unittest_type),allocatable,intent(out) :: testsuite(:)
    testsuite = [ &
      new_unittest("U1 no-restraint identity       ",test_no_restraint), &
      new_unittest("U2 single restraint            ",test_single_restraint), &
      new_unittest("U3 raw same-geometry SP       ",test_raw_same_geometry), &
      new_unittest("U4 multiple restraint sum      ",test_multiple_restraints), &
      new_unittest("U5 coord component copy        ",test_coord_copy), &
      new_unittest("U6 plain XYZ roundtrip         ",test_plain_xyz), &
      new_unittest("U7 extxyz roundtrip            ",test_extxyz), &
      new_unittest("U8 legacy XYZ fallback         ",test_legacy_xyz) &
    ]
  end subroutine collect_gmc_energy

  subroutine make_gfn2(calc)
    type(calcdata),intent(out) :: calc
    type(calculation_settings) :: sett
    call sett%create('gfn2')
    call calc%add(sett)
  end subroutine make_gfn2

  subroutine require_valid(error,mol)
    type(error_type),allocatable,intent(inout) :: error
    type(coord),intent(in) :: mol
    if (.not.mol%energy_components_valid) then
      call test_failed(error,'energy components are not marked valid')
    end if
  end subroutine require_valid

  subroutine assert_components(error,mol,raw,restraint,total)
    type(error_type),allocatable,intent(inout) :: error
    type(coord),intent(in) :: mol
    real(wp),intent(in) :: raw,restraint,total
    call require_valid(error,mol)
    if (allocated(error)) return
    call check(error,mol%energy_raw,raw,thr=tol)
    if (allocated(error)) return
    call check(error,mol%energy_restraint,restraint,thr=tol)
    if (allocated(error)) return
    call check(error,mol%energy_total,total,thr=tol)
    if (allocated(error)) return
    call check(error,mol%energy,total,thr=tol)
    if (allocated(error)) return
    if (abs(mol%energy_total-mol%energy_raw-mol%energy_restraint) > tol) then
      call test_failed(error,'energy component identity is violated')
    end if
  end subroutine assert_components

  subroutine test_no_restraint(error)
    type(error_type),allocatable,intent(out) :: error
    type(calcdata) :: calc
    type(coord) :: mol
    real(wp) :: energy
    real(wp),allocatable :: grad(:,:)
    integer :: io
    call make_gfn2(calc)
    call get_testmol('methane',mol)
    allocate (grad(3,mol%nat))
    call engrad(mol,calc,energy,grad,io)
    call check(error,io,0)
    if (allocated(error)) return
    call assert_components(error,mol,energy,0.0_wp,energy)
  end subroutine test_no_restraint

  subroutine make_bond(mol,i,j,delta,k,constr)
    type(coord),intent(in) :: mol
    integer,intent(in) :: i,j
    real(wp),intent(in) :: delta,k
    type(constraint),intent(out) :: constr
    call constr%bondconstraint(i,j,mol%dist(i,j)+delta,k)
  end subroutine make_bond

  subroutine test_single_restraint(error)
    type(error_type),allocatable,intent(out) :: error
    type(calcdata) :: plain,constrained
    type(constraint) :: constr
    type(coord) :: mol,reference
    real(wp) :: eplain,energy,delta,k
    real(wp),allocatable :: grad(:,:)
    integer :: io
    call make_gfn2(plain)
    call constrained%copy(plain)
    call get_testmol('methane',reference)
    mol = reference
    delta = 0.20_wp
    k = 1.0_wp
    call make_bond(reference,1,2,delta,k,constr)
    call constrained%add(constr)
    allocate (grad(3,mol%nat))
    call engrad(reference,plain,eplain,grad,io)
    call check(error,io,0)
    if (allocated(error)) return
    call engrad(mol,constrained,energy,grad,io)
    call check(error,io,0)
    if (allocated(error)) return
    call check(error,mol%energy_raw,eplain,thr=tol)
    if (allocated(error)) return
    call check(error,mol%energy_restraint,0.5_wp*k*delta**2,thr=tol)
    if (allocated(error)) return
    call check(error,mol%energy_total,mol%energy_raw+mol%energy_restraint,thr=tol)
    if (allocated(error)) return
    call check(error,mol%energy,energy,thr=tol)
  end subroutine test_single_restraint

  subroutine test_raw_same_geometry(error)
    type(error_type),allocatable,intent(out) :: error
    type(calcdata) :: plain,constrained
    type(constraint) :: constr
    type(coord) :: mol,reference
    real(wp) :: eplain,energy
    real(wp),allocatable :: grad(:,:)
    integer :: io
    call make_gfn2(plain)
    call constrained%copy(plain)
    call get_testmol('methane',reference)
    mol = reference
    call make_bond(reference,1,2,0.35_wp,2.0_wp,constr)
    call constrained%add(constr)
    allocate (grad(3,mol%nat))
    call engrad(reference,plain,eplain,grad,io)
    call check(error,io,0)
    if (allocated(error)) return
    call engrad(mol,constrained,energy,grad,io)
    call check(error,io,0)
    if (allocated(error)) return
    call check(error,mol%energy_raw,eplain,thr=tol)
    if (allocated(error)) return
    if (abs(mol%energy_total-energy) > tol) then
      call test_failed(error,'coord energy is not the calculator total')
    end if
  end subroutine test_raw_same_geometry

  subroutine test_multiple_restraints(error)
    type(error_type),allocatable,intent(out) :: error
    type(calcdata) :: calc
    type(constraint) :: c1,c2
    type(coord) :: mol
    real(wp) :: d1,d2,k1,k2,expected,energy
    real(wp),allocatable :: grad(:,:)
    integer :: io
    call make_gfn2(calc)
    call get_testmol('methane',mol)
    d1 = 0.15_wp
    d2 = 0.25_wp
    k1 = 1.5_wp
    k2 = 2.5_wp
    call make_bond(mol,1,2,d1,k1,c1)
    call make_bond(mol,1,3,d2,k2,c2)
    call calc%add(c1)
    call calc%add(c2)
    allocate (grad(3,mol%nat))
    call engrad(mol,calc,energy,grad,io)
    call check(error,io,0)
    if (allocated(error)) return
    expected = 0.5_wp*k1*d1**2+0.5_wp*k2*d2**2
    call check(error,mol%energy_restraint,expected,thr=tol)
    if (allocated(error)) return
    call check(error,mol%energy_total,mol%energy_raw+expected,thr=tol)
  end subroutine test_multiple_restraints

  subroutine test_coord_copy(error)
    type(error_type),allocatable,intent(out) :: error
    type(coord) :: source,target
    call get_testmol('methane',source)
    call source%set_energy_components(-10.002_wp,0.002_wp,-10.000_wp)
    call target%copy(source)
    call assert_components(error,target,-10.002_wp,0.002_wp,-10.000_wp)
  end subroutine test_coord_copy

  subroutine test_plain_xyz(error)
    type(error_type),allocatable,intent(out) :: error
    type(coord) :: source,target
    character(len=*),parameter :: fname = 'gmc_energy_roundtrip.xyz'
    call get_testmol('methane',source)
    call source%set_energy_components(-10.002_wp,0.002_wp,-10.000_wp)
    call source%write(fname)
    call target%open(fname)
    call assert_components(error,target,-10.002_wp,0.002_wp,-10.000_wp)
    call remove_file(fname)
  end subroutine test_plain_xyz

  subroutine test_extxyz(error)
    type(error_type),allocatable,intent(out) :: error
    type(coord) :: source,target
    character(len=*),parameter :: fname = 'gmc_energy_roundtrip.extxyz'
    call get_testmol('methane',source)
    call source%set_energy_components(-10.002_wp,0.002_wp,-10.000_wp)
    source%wrextxyz = .true.
    call source%write(fname)
    call target%open(fname)
    call assert_components(error,target,-10.002_wp,0.002_wp,-10.000_wp)
    call remove_file(fname)
  end subroutine test_extxyz

  subroutine test_legacy_xyz(error)
    type(error_type),allocatable,intent(out) :: error
    type(coord) :: source,target
    real(wp) :: ranked
    character(len=*),parameter :: fname = 'gmc_energy_legacy.xyz'
    call get_testmol('methane',source)
    source%energy = -12.345_wp
    call source%invalidate_energy_components()
    call source%write(fname)
    call target%open(fname)
    if (target%energy_components_valid) then
      call test_failed(error,'legacy XYZ unexpectedly has valid components')
      call remove_file(fname)
      return
    end if
    ranked = target%ranking_energy()
    call check(error,ranked,target%energy,thr=tol)
    call remove_file(fname)
  end subroutine test_legacy_xyz

  subroutine remove_file(fname)
    character(len=*),intent(in) :: fname
    logical :: exists
    integer :: iunit,io
    inquire (file=fname,exist=exists)
    if (exists) then
      open (newunit=iunit,file=fname,status='old',iostat=io)
      if (io == 0) close (iunit,status='delete')
    end if
  end subroutine remove_file

end module test_gmc_energy
