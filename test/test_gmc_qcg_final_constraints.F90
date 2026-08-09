module test_gmc_qcg_final_constraints
  use testdrive,only:new_unittest,unittest_type,error_type,check,test_failed
  use crest_parameters,only:wp,aatoau,pi
  use crest_calculator
  use parse_xtbinput,only:parse_qcg_final_constraints
  use strucrd
  use crest_testmol,only:get_testmol
  implicit none
  private

  public :: collect_gmc_qcg_final_constraints

contains

  subroutine collect_gmc_qcg_final_constraints(testsuite)
    type(unittest_type),allocatable,intent(out) :: testsuite(:)
    testsuite = [ &
      new_unittest('A2 valid numeric distance angle dihedral',test_valid), &
      new_unittest('A2 invalid final constraint inputs       ',test_invalid) &
    ]
  end subroutine collect_gmc_qcg_final_constraints

  subroutine write_case(fname,lines)
    character(len=*),intent(in) :: fname,lines(:)
    integer :: unit,i
    open (newunit=unit,file=fname,status='replace',action='write')
    do i = 1,size(lines)
      write (unit,'(a)') trim(lines(i))
    end do
    close (unit)
  end subroutine write_case

  subroutine remove_case(fname)
    character(len=*),intent(in) :: fname
    logical :: ex
    integer :: unit
    inquire (file=fname,exist=ex)
    if (ex) then
      open (newunit=unit,file=fname,status='old')
      close (unit,status='delete')
    end if
  end subroutine remove_case

  subroutine test_valid(error)
    type(error_type),allocatable,intent(out) :: error
    type(calcdata) :: calc
    type(coord) :: mol
    character(len=128) :: lines(6)
    integer :: io
    lines = [character(len=128) :: '$constrain', 'force constant=0.50', &
      'distance: 1,2,1.50', 'angle: 1,2,3,109.5', &
      'dihedral: 1,2,3,4,180.0', '$end']
    call get_testmol('methane',mol)
    call write_case('gmc_qcg_final_valid.inp',lines)
    call parse_qcg_final_constraints(calc,mol,'gmc_qcg_final_valid.inp',4,io)
    call remove_case('gmc_qcg_final_valid.inp')
    call check(error,io,0)
    if (allocated(error)) return
    call check(error,calc%nconstraints,3)
    if (allocated(error)) return
    call check(error,calc%cons(1)%n,2)
    if (allocated(error)) return
    call check(error,calc%cons(1)%ref(1),1.50_wp*aatoau,thr=1.0e-12_wp)
    if (allocated(error)) return
    call check(error,calc%cons(1)%fc(1),0.50_wp,thr=1.0e-12_wp)
    if (allocated(error)) return
    call check(error,calc%cons(2)%n,3)
    if (allocated(error)) return
    call check(error,calc%cons(2)%ref(1),109.5_wp*pi/180.0_wp,thr=1.0e-12_wp)
    if (allocated(error)) return
    call check(error,calc%cons(3)%n,4)
    if (allocated(error)) return
    call check(error,calc%cons(3)%ref(1),pi,thr=1.0e-12_wp)
  end subroutine test_valid

  subroutine assert_rejected(error,fname,lines,mol)
    type(error_type),allocatable,intent(inout) :: error
    character(len=*),intent(in) :: fname,lines(:)
    type(coord),intent(in) :: mol
    type(calcdata) :: calc
    integer :: io
    call write_case(fname,lines)
    call parse_qcg_final_constraints(calc,mol,fname,4,io)
    call remove_case(fname)
    call check(error,io,1)
    if (allocated(error)) return
    call check(error,calc%nconstraints,0)
  end subroutine assert_rejected

  subroutine test_invalid(error)
    type(error_type),allocatable,intent(out) :: error
    type(coord) :: mol
    character(len=128) :: lines(3),partial(4)
    call get_testmol('methane',mol)
    lines = [character(len=128) :: '$constrain','distance: 1,2,auto','$end']
    call assert_rejected(error,'gmc_qcg_final_auto.inp',lines,mol)
    if (allocated(error)) return
    lines = [character(len=128) :: '$constrain','reference=coord.ref','$end']
    call assert_rejected(error,'gmc_qcg_final_ref.inp',lines,mol)
    if (allocated(error)) return
    lines = [character(len=128) :: '$wall','sphere: auto','$end']
    call assert_rejected(error,'gmc_qcg_final_wall.inp',lines,mol)
    if (allocated(error)) return
    lines = [character(len=128) :: '$constrain','distance: 1,5,1.50','$end']
    call assert_rejected(error,'gmc_qcg_final_solvent.inp',lines,mol)
    if (allocated(error)) return
    lines = [character(len=128) :: '$constrain','distance: 1,1,1.50','$end']
    call assert_rejected(error,'gmc_qcg_final_duplicate_distance.inp',lines,mol)
    if (allocated(error)) return
    lines = [character(len=128) :: '$constrain','angle: 1,2,1,109.5','$end']
    call assert_rejected(error,'gmc_qcg_final_duplicate_angle.inp',lines,mol)
    if (allocated(error)) return
    lines = [character(len=128) :: '$constrain','dihedral: 1,2,3,2,180.0','$end']
    call assert_rejected(error,'gmc_qcg_final_duplicate_dihedral.inp',lines,mol)
    if (allocated(error)) return
    lines = [character(len=128) :: '$constrain','distance: 1,2','$end']
    call assert_rejected(error,'gmc_qcg_final_malformed.inp',lines,mol)
    if (allocated(error)) return
    lines = [character(len=128) :: '$constrain','force constant=bad','$end']
    call assert_rejected(error,'gmc_qcg_final_bad_force.inp',lines,mol)
    if (allocated(error)) return
    lines = [character(len=128) :: '$constrain','coord.ref=coord.ref','$end']
    call assert_rejected(error,'gmc_qcg_final_coord_ref.inp',lines,mol)
    if (allocated(error)) return
    partial = [character(len=128) :: '$constrain','distance: 1,2,1.50', &
      'unsupported=1','$end']
    call assert_rejected(error,'gmc_qcg_final_partial.inp',partial,mol)
    if (allocated(error)) return
    call parse_qcg_final_constraints_dummy(error,mol)
  end subroutine test_invalid

  subroutine parse_qcg_final_constraints_dummy(error,mol)
    type(error_type),allocatable,intent(inout) :: error
    type(coord),intent(in) :: mol
    type(calcdata) :: calc
    integer :: io
    call parse_qcg_final_constraints(calc,mol,'gmc_qcg_final_missing.inp',4,io)
    call check(error,io,1)
  end subroutine parse_qcg_final_constraints_dummy

end module test_gmc_qcg_final_constraints
